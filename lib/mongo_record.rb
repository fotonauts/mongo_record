# Copyright 2009-2010 10gen, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Include files for using Mongo, MongoRecord::Base, and a database logger.

require 'rubygems'
require 'mongo'
require 'mongo_record/base'
require 'mongo_record/subobject'
require 'mongo_record/log_device'

Kernel.warn "Note: MongoRecord is no longer supported by its authors." +
  "For a list of MongoDB object mappers, see http://is.gd/gdehy."
