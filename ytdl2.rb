#!/usr/bin/env ruby
# frozen_string_literal: true

# playlist name calculation code
playlistpath =
  case
  when Args.playlistpath
    Args.playlistpath
  when [Directory.to_s.include?('/data/Videos/Youtube'), Args.subdirectory].all?
    Pathname.new("/data/Videos/Youtube/Playlists/#{Args.subdirectory}/#{Args.date}.xspf")
  when [Directory.to_s.include?('/data/Videos/Youtube'), !Args.subdirectory].all?
    Pathname.new("/data/Videos/Youtube/Playlists/#{Args.date}.xspf")
  else
    Pathname.new("#{Directory}/Playlists/#{Args.date}.xspf")
  end
