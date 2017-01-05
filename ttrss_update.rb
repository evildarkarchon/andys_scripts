#!/usr/bin/env ruby

require_relative 'andyrb/util'
require_relative 'andyrb/git'
require_relative 'andyrb/mood'

TTRss = Git.new('/data/web/feeds', use_sudo = True, sudo_user = 'nginx')
at_exit do
  TTRss.clean_lock
end
