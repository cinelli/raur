#!/usr/bin/env ruby
#
# raur
# A simple AUR helper in Ruby
# Depends on pacman, makepkg, sudo
# https://github.com/Boohbah/raur
# https://aur.archlinux.org/packages/raur-git
#
# Copyright (c) 2013 Boohbah <boohbah at gmail.com>
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

aurdir = "/home/user/aur" # Change this

unless File.directory? aurdir
  raise Errno::ENOENT, aurdir
end

require 'open-uri'
require 'io/console'
require 'rubygems/package'
require 'fileutils' # For ruby versions < 2.0.0

# https://gist.github.com/sinisterchipmunk/1335041
def untar(io, destination)
  Gem::Package::TarReader.new io do |tar|
    tar.each do |tarfile|
      destination_file = File.join destination, tarfile.full_name

      if tarfile.directory?
        FileUtils.mkdir_p destination_file
      else
        destination_directory = File.dirname(destination_file)

        unless File.directory?(destination_directory)
          FileUtils.mkdir_p destination_directory
        end

        File.open destination_file, "wb" do |f|
          f.print tarfile.read
        end
      end
    end
  end
end

pkg = ARGV.first

if pkg.nil?
  raise "No argument given. Specify the AUR package you want to build.\n" +
        "Usage: raur pkgname"
end

# Check for required executables
%w(/usr/bin/pacman /usr/bin/makepkg /usr/bin/sudo).each do |file|
  unless File.executable? file
    raise "#{file} does not exist or is not executable."
  end
end

pkgdir = "#{aurdir}/#{pkg}"

# Determine if a package directory with this name exists
if File.directory? pkgdir
  print "Remove existing directory #{pkgdir} ? [y/N] "
  puts input = STDIN.getch
  case input
  when 'y', 'Y'
    puts "Removing #{pkgdir}"
    FileUtils.rm_rf pkgdir
  else
    puts "Writing over existing #{pkgdir}"
  end
end

url = "https://aur.archlinux.org/packages/#{pkg[0..1]}/#{pkg}/#{pkg}.tar.gz"
tarball = "#{aurdir}/#{pkg}.tar.gz"

# Download tarball
begin
  resp = open(url)
rescue OpenURI::HTTPError
  abort "#{url}\n#{$!}"
end

# Write response after handling possible HTTP error
File.open(tarball, 'wb') {|f| f.write resp.read }

# Extract
tgz = Zlib::GzipReader.new(File.open(tarball, 'rb'))
untar tgz, aurdir

# Build
Dir.chdir pkgdir
unless system "makepkg -sf"
  raise "makepkg failed."
end

# Find newest file
pkgfile = Dir.entries(pkgdir).sort_by {|f|
  File.mtime(File.join(pkgdir, f))
}.last

# Install
unless system "sudo pacman -U #{pkgfile}"
  raise "Failed to install #{pkgfile}"
end

# Cleanup
File.delete tarball

puts "Installed #{pkg}"
