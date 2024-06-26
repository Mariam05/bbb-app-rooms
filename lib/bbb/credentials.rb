# frozen_string_literal: true

#  BigBlueButton open source conferencing system - http://www.bigbluebutton.org/.
#
#  Copyright (c) 2020 BigBlueButton Inc. and by respective authors (see below).
#
#  This program is free software; you can redistribute it and/or modify it under the
#  terms of the GNU Lesser General Public License as published by the Free Software
#  Foundation; either version 3.0 of the License, or (at your option) any later
#  version.
#
#  BigBlueButton is distributed in the hope that it will be useful, but WITHOUT ANY
#  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
#  PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details.
#
#  You should have received a copy of the GNU Lesser General Public License along
#  with BigBlueButton; if not, see <http://www.gnu.org/licenses/>.

require 'net/http'
require 'xmlsimple'
require 'json'

module Bbb
  class Credentials
    include OmniauthHelper
    include BrokerHelper

    attr_writer :cache, :cache_enabled, :multitenant_api_endpoint, :multitenant_api_secret # Rails.cache store is assumed.  # Enabled by default.

    def initialize(endpoint, secret)
      # Set default credentials.
      @endpoint = endpoint
      @secret = secret
      @multitenant_api_endpoint = nil
      @multitenant_api_secret = nil
      @cache_enabled = true
    end

    def endpoint(tenant)
      fix_bbb_endpoint_format(tenant_endpoint(tenant))
    end

    def secret(tenant)
      tenant_secret(tenant)
    end

    private

    def tenant_endpoint(tenant)
      tenant_info(tenant, 'apiURL')
    end

    def tenant_secret(tenant)
      tenant_info(tenant, 'secret')
    end

    def tenant_info(tenant, key)
      info = formatted_tenant_info(tenant)
      return if info.nil?

      info[key]
    end

    def formatted_tenant_info(tenant)
      if @cache_enabled
        Rails.logger.debug('Cache enabled, attempt to fetch credentials from cache...')
        cached_tenant = @cache.fetch("rooms/#{tenant}/tenantInfo", expires_in: Rails.configuration.cache_expires_in_minutes.minutes)
        return cached_tenant unless cached_tenant.nil?
      end

      # Get tenant info from broker
      Rails.logger.debug('No cache. Attempt to fetch credentials from broker...')
      tenant_info = broker_tenant_info(tenant)

      # Get tenant credentials from TENANT_CREDENTIALS environment variable
      tenant_credentials = JSON.parse(Rails.configuration.tenant_credentials)[tenant]

      raise 'Tenant does not exist' if tenant_info.nil? && tenant_credentials.nil? && tenant.present?

      # use credentials from broker first, if not found then use env variable, and then use bbb_endpoint &  bbb_secret if single tenant
      tenant_settings = tenant_info&.[]('settings')

      api_url = tenant_settings&.[]('bigbluebutton_url') ||
                tenant_credentials&.[]('bigbluebutton_url') ||
                (@endpoint if tenant.blank?)

      secret = tenant_settings&.[]('bigbluebutton_secret') ||
               tenant_credentials&.[]('bigbluebutton_secret') ||
               (@secret if tenant.blank?)

      missing_creds = !(api_url && secret)

      raise 'Bigbluebutton credentials not found' if tenant.blank? && missing_creds

      raise 'Multitenant API not defined' if tenant.present? && missing_creds && (@multitenant_api_endpoint.nil? || @multitenant_api_secret.nil?)

      # get the api URL and secret from the LB if not defined in tenant settings
      if missing_creds
        Rails.logger.debug('Missing credentials, attempt to fetch from multitenant_api_endpoint...')
        # Build the URI.
        uri = encoded_url(
          "#{@multitenant_api_endpoint}api/getUser",
          @multitenant_api_secret,
          { name: tenant }
        )

        http_response = http_request(uri)
        response = parse_response(http_response)
        response['settings'] = tenant_settings
      end

      @cache.fetch("rooms/#{tenant}/tenantInfo", expires_in: Rails.configuration.cache_expires_in_minutes.minutes) do
        response || { 'apiURL' => api_url, 'secret' => secret, 'settings' => tenant_settings }
      end
    end

    def http_request(uri)
      # Make the request.
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      response = http.get(uri.request_uri)
      raise 'Error on response' unless response.is_a?(Net::HTTPSuccess)

      response
    end

    def parse_response(response)
      # Parse XML.
      doc = XmlSimple.xml_in(response.body, 'ForceArray' => false)

      raise doc['message'] unless response.is_a?(Net::HTTPSuccess)

      # Return the user credentials if the request succeeded on the External Tenant Manager.
      return doc['user'] if doc['returncode'] == 'SUCCESS'

      raise "User with tenant #{tenant} does not exist." if doc['messageKey'] == 'noSuchUser'

      raise "API call #{url} failed with #{doc['messageKey']}."
    end

    def encoded_url(endpoint, secret, params)
      encoded_params = params.to_param
      string = "getUser#{encoded_params}#{secret}"
      checksum_algorithm = Rails.configuration.checksum_algorithm
      checksum = OpenSSL::Digest.digest(checksum_algorithm, string).unpack1('H*')
      URI.parse("#{endpoint}?#{encoded_params}&checksum=#{checksum}")
    end

    # Fixes BigBlueButton endpoint ending.
    def fix_bbb_endpoint_format(endpoint)
      # Fix endpoint format only if required.
      endpoint += '/' unless endpoint.ends_with?('/')
      endpoint += 'api/' if endpoint.ends_with?('bigbluebutton/')
      endpoint += 'bigbluebutton/api/' unless endpoint.ends_with?('bigbluebutton/api/')
      endpoint
    end
  end
end
