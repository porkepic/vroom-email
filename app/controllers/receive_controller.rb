require "net/http"
require 'net/https'
require "uri"

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
    render json: {}
  end

  def delivery
    postmark("delivery")
    render json: {}
  end

  def open
    postmark("open")
    render json: {}
  end

  def postmark(event)
    raw_json = request.raw_post
    json = JSON.parse raw_json
    logger = Rails.logger

    return unless json["Tag"]
    tag = nil
    begin
      tag = JSON.parse json["Tag"]
    rescue => e
      return
    end

    subdomain = tag["subdomain"]
    tag["event"] = event

    logger.info "[#{subdomain}] : receive '#{event}' with '#{tag["object"]}'"

    return unless subdomain

    uri = URI.parse("https://#{ENV["RECEIVE_USER"]}:#{ENV["RECEIVE_PASSWORD"]}@#{subdomain}")
    Net::HTTP.post_form(uri, tag)
  end

end
