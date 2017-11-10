require "net/http"
require 'net/https'
require "uri"
require "rollbar"
require 'base64'

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
    # postmark("bounce")
    enqueue("bounce")

    render json: {}
  end

  def delivery
    # postmark("delivered")
    enqueue("delivered")

    render json: {}
  end

  def open
    # postmark("open")
    enqueue("open")

    render json: {}
  end

  def enqueue(event)
    raw_json = request.raw_post
    json = JSON.parse raw_json
    logger = Rails.logger

    json_tag = json["Tag"]
    return if !json_tag || json_tag == ""
    tag = nil

    if json_tag[0] != "{" && json_tag[-1] != "}"
      json_tag = Base64.decode64(json_tag)
    end

    begin
      tag = JSON.parse json_tag.gsub(/\s|\\t/, "")
    rescue => e
      Rollbar.error(e)
      return
    end

    subdomain = tag["subdomain"]
    tag["event"] = event

    return unless subdomain

    begin
      matcher = /([^\.]*)\.inc\.construction/
      tenant = nil
      if subdomain.end_with?( "local.host")
        matcher = /([^\.]*)\.local\.host/
        queue = "dev_default"
      elsif subdomain == "fca.inc.construction"
        queue = "fca_default"
        tenant = ["","public"]
      elsif subdomain == "durotoit.inc.construction"
        queue = "durotoit_default"
        tenant = ["","public"]
      elsif subdomain.end_with?( ".inc.services")
        matcher = /([^\.]*)\.inc\.services/
        queue = "ccube_staging_default"
      else
        queue = "ccube_prod_default"
      end

      if !tenant
        tenant = subdomain.match( matcher )
      end
      logger.info "#{subdomain} #{queue} - #{tenant ? tenant[1] : "nil"} : receive '#{tag["event"]}' with '#{tag["object"]}'"

      if tenant && queue

        tag["tenant"] = tenant[1]
        # avoid improper loading of gid
        tag["object"] = "nogid-#{tag["object"]}"

        EmailEventJob.set(queue: queue).perform_later(tag)

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

    return if !subdomain || subdomain.end_with?("local.host")

    uri = URI.parse("https://#{ENV["RECEIVE_USER"]}:#{ENV["RECEIVE_PASSWORD"]}@#{subdomain}/emails")
    Net::HTTP.post_form(uri, tag)
  end

end
