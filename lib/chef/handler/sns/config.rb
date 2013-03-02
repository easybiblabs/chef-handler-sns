#
# Author:: Xabier de Zuazo (<xabier@onddo.com>)
# Copyright:: Copyright (c) 2013 Onddo Labs, SL.
# License:: Apache License, Version 2.0
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
#

require 'chef/mixin/params_validate'
require 'chef/exceptions'

class Chef
  class Handler
    class Sns
      module Config
        include ::Chef::Mixin::ParamsValidate
      
        def config_init(config={})
          config.each do |key, value|
            if self.respond_to?(key)
              self.send(key, value)
            else
              Chef::Log.warn("#{self.class.to_s}: cnofiguration method not found: #{key}.")
            end
          end
        end
      
        def config_check
          required = [ 'access_key', 'secret_key', 'topic_arn' ]
          opts = {}
          map = {}
          required.each do |key|
            opts[key] = self.send(key)
            map[key] = { :required => true }
          end
          validate(opts, map)
      
          if body_template and not ::File.exists?(body_template)
            raise Exceptions::ValidationFailed,
              "Template file not found: #{body_template}."
          end
        end
      
        def access_key(arg=nil)
          set_or_return(
            :access_key,
            arg,
            :kind_of => String
          )
        end
      
        def secret_key(arg=nil)
          set_or_return(
            :secret_key,
            arg,
            :kind_of => String
          )
        end
      
        def region(arg=nil)
          set_or_return(
            :region,
            arg,
            :kind_of => String
          )
        end
      
        def token(arg=nil)
          set_or_return(
            :token,
            arg,
            :kind_of => String
          )
        end
      
        def topic_arn(arg=nil)
          set_or_return(
            :topic_arn,
            arg,
            :kind_of => String
          )
        end
      
        def subject(arg=nil)
          set_or_return(
            :subject,
            arg,
            :kind_of => String
          )
        end
      
        def body_template(arg=nil)
          set_or_return(
            :body_template,
            arg,
            :kind_of => String
          )
        end
      
      end
    end 
  end 
end 