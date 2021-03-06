# encoding: UTF-8

# Copyright 2011-2013 innoQ Deutschland GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

class AbstractUser < ActiveRecord::Base
  self.table_name = 'users'

  delegate :can?, :cannot?, :to => :ability

  validates_presence_of :email
  validates_uniqueness_of :email
  # validates_format_of :email, with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i

  acts_as_authentic do |config|
    config.validate_email_field = false
    config.maintain_sessions = false
    config.crypto_provider = Authlogic::CryptoProviders::Sha512 # use authlogic's old crypto provider
  end

  def self.default_role
    'reader'
  end

  def name
    "#{forename} #{surname}"
  end

  def to_s
    self.name.to_s
  end

  def owns_role?(name)
    self.role == name.to_s
  end

  def ability
    @ability ||= Ability.new(self)
  end
end
