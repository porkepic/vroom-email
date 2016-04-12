require "net/http"
require 'net/https'
require "uri"

class ReceiveController < ApplicationController
  include ActionController::HttpAuthentication::Basic::ControllerMethods

  http_basic_authenticate_with name: ENV["RECEIVE_USER"], password: ENV["RECEIVE_PASSWORD"]

  def email
    raw_json = request.raw_post
    json = JSON.parse raw_json
    logger = Rails.logger

    json.each do |event|

      subdomain = event["subdomain"]

      logger.info "[#{subdomain}] : receive '#{event["event"]}' with '#{event["object"]}', '#{event["email"]}'"

      next unless subdomain
      
      uri = URI.parse("https://#{subdomain}.#{ENV["RECEIVE_DOMAIN"]}")
      Net::HTTP.post_form(uri, event)

    end

    render json: {}    
  end

end
