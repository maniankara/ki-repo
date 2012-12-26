# encoding: UTF-8

# Copyright 2012 Mikko Apo
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'rubygems'
require 'rspec'
require 'mocha/api'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

RSpec.configure do |config|
  config.mock_with :mocha
end

require 'simplecov'
SimpleCov.start do
  add_filter "/spec/"
end

require 'ki_repo_all'
include Ki

# Override user's own ki-repository settings
ENV["KIHOME"]=File.dirname(File.dirname(File.expand_path(__FILE__)))

# common helper methods

def try(retries, retry_sleep, &block)
  c = 0
  start = Time.now
  while c < retries
    begin
      return block.call(c+1)
    rescue Exception => e
      c += 1
      if c < retries
        sleep retry_sleep
      else
        raise e.class, e.message + " (tried #{c} times, waited #{sprintf("%.2f", Time.now - start)} seconds)", e.backtrace
      end
    end
  end
end

def restore_extensions
  original_commands = KiCommand::KiExtensions.dup
  @tester.cleaners << lambda do
    KiCommand::KiExtensions.clear
    KiCommand::KiExtensions.register(original_commands)
  end
end
