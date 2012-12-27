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

module Ki

  # Tries to launch Rack handlers in default order
  # @see RackCommand
  class DefaultRackHandler
    def run(app, config={})
      rack_app = Rack::Builder.new do
        map "/" do
          run app
        end
      end
      detect_rack_handler.run(rack_app, config) do |server|
        @server = server
      end
    end

    def stop
      @server.stop
    end

    def detect_rack_handler
      servers = %W(thin mongrel webrick)
      servers.each do |server_name|
        begin
          return Rack::Handler.get(server_name.to_s)
        rescue Exception
        end
      end
      fail "Could not resolve server handlers for any of '#{servers.join(', ')}'."
    end
  end
end