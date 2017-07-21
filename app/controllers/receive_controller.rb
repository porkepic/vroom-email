require "net/http"
require 'net/https'
require "uri"
require "rollbar"

class ReceiveController < ApplicationController
  include ActionController::HttpAuthentication::Basic::ControllerMethods

  http_basic_authenticate_with name: ENV["RECEIVE_USER"], password: ENV["RECEIVE_PASSWORD"]

  MAP_TO_SENDGRID_EVENTS = {

  }

  def email
    raw_json = request.raw_post
    json = JSON.parse raw_json
    logger = Rails.logger

    json.each do |event|

      subdomain = event["subdomain"]

      logger.info "[#{subdomain}] : receive '#{event["event"]}' with '#{event["object"]}', '#{event["email"]}'"

      next unless subdomain

      uri = URI.parse("https://#{ENV["RECEIVE_USER"]}:#{ENV["RECEIVE_PASSWORD"]}@#{subdomain}.#{ENV["RECEIVE_DOMAIN"]}")
      Net::HTTP.post_form(uri, event)

    end

    render json: {}
  end

  def bounce
    postmark("bounce")
    enqueue("bounce")

    render json: {}
  end

  def delivery
    postmark("delivered")
    enqueue("delivered")

    render json: {}
  end

  def open
    postmark("open")
    enqueue("open")

    render json: {}
  end

  def enqueue(event)
    raw_json = request.raw_post
    json = JSON.parse raw_json
    logger = Rails.logger

    return if !json["Tag"] || json["Tag"] == ""
    tag = nil
    begin
      tag = JSON.parse json["Tag"].gsub(/\s|\\t/, "")
    rescue => e
      Rollbar.error(e)
      return
    end

    subdomain = tag["subdomain"]
    tag["event"] = event

    return unless subdomain

    begin
      matcher = /([^\.]*)\.inc.construction/
      queue = case subdomain
      when subdomain.end_with?( ".local.host")
        matcher = /([^\.]*)\.local.host/
        "dev_default"
      # when subdomain == "fca.inc.construction"
      #   "fca_default"
      # when subdomain == "durotoit.inc.construction"
      #   "durotoit_default"
      # when subdomain.end_with?( ".inc.services")
      #   matcher = /([^\.]*)\.inc.services/
      #   "ccube_staging_default"
      # else
      #   "ccube_prod_default"
      else
        nil
      end

      tenant = subdomain.match( matcher )
      logger.info "#{queue} - #{tenant} : receive '#{tag["event"]}' with '#{tag["object"]}'"

      if tenant && queue
        Shoryuken::Client.queues(queue).send_message({
          message_body: tag,
          message_attributes: {
            tenant: {
              string_value: tenant[1],
              data_type: "String"
            }
          }
        })
      end
    rescue => e
      Rollbar.error(e)
      return
    end

  end

  def postmark(event)
    raw_json = request.raw_post
    json = JSON.parse raw_json
    logger = Rails.logger

    return if !json["Tag"] || json["Tag"] == ""
    tag = nil
    begin
      tag = JSON.parse json["Tag"].gsub(/\s|\\t/, "")
    rescue => e
      Rollbar.error(e)
      return
    end

    subdomain = tag["subdomain"]
    tag["event"] = event

    logger.info "[#{subdomain}] : receive '#{tag["event"]}' with '#{tag["object"]}'"

    return unless subdomain

    uri = URI.parse("https://#{ENV["RECEIVE_USER"]}:#{ENV["RECEIVE_PASSWORD"]}@#{subdomain}/emails")
    Net::HTTP.post_form(uri, tag)
  end

end
