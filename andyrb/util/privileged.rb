require 'etc'
require 'pathname'

module Util
  def self.privileged?(user = 'root', path = nil)
    currentuser = Etc.getpwuid unless path
    value = false
    path &&= Pathname.new(path) unless path.is_a?(Pathname)
    privuser =
      case
      when user.respond_to?(:to_s) && !path
        Etc.getpwnam(user)
      when user.respond_to?(:to_i) && !path
        Etc.getpwuid(user.to_i)
      end
    # value = true if currentuser.uid == privuser.uid && !path
    # value = true if path && path.respond_to?(:writable?) && path.writable?
    value =
      case
      when path && path.respond_to?(:writable?) && path.writable?, currentuser.uid == privuser.uid && !path
        true
      end
    yield value if block_given?
    value
  end
end
