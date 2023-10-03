# frozen_string_literal: true

# BigBlueButton open source conferencing system - http://www.bigbluebutton.org/.
# Copyright (c) 2018 BigBlueButton Inc. and by respective authors (see below).
# This program is free software; you can redistribute it and/or modify it under the
# terms of the GNU Lesser General Public License as published by the Free Software
# Foundation; either version 3.0 of the License, or (at your option) any later
# version.
# BigBlueButton is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details.

# You should have received a copy of the GNU Lesser General Public License along
# with BigBlueButton; if not, see <http://www.gnu.org/licenses/>.

module BrokerHelper
  extend ActiveSupport::Concern

  include OmniauthHelper

  # Fetch tenant settings from the broker
  def tenant_settings
    bbbltibroker_url = omniauth_bbbltibroker_url("/api/v1/tenants/#{@room.tenant}")
    get_response = RestClient.get(bbbltibroker_url, 'Authorization' => "Bearer #{omniauth_client_token(omniauth_bbbltibroker_url)}")
    JSON.parse(get_response)
  rescue StandardError => e
    Rails.logger.error("Could not fetch tenant credentials from broker. Error message: #{e}")
    nil
  end

  # Fetch the settings to be forwarded to BBB on join or create
  # TO DO: Cache this info
  %w[join create].each do |action|
    name = "forward_params_#{action}"
    define_method name do
      tenant_settings&.[]('settings')&.[](name)
    end
  end
end
