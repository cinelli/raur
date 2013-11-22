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

url	= "https://aur.archlinux.org/packages/"
aurdir	= Dir.getwd

require 'open-uri'
require 'io/console'
require 'rubygems/package'
require 'fileutils' # For ruby versions < 2.0.0

unless `type -a pacman >/dev/null` && `type -a makepkg >/dev/null` && `type -a sudo >/dev/null`
  abort("ERROR: Missing a required dependancy: pacman, makepkg, sudo")
end

def ask(question)
  puts question
  response = STDIN.gets.chomp
  case(response)
  when /^y(es)?$/i
    true
  when /^no?$/i
    false
  else
    ask question
  end
end

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
  abort("ERROR: No argument given. Specify the AUR package you want to build.\nUsage: raur pkgname")
end

tarDL	= "#{url}/#{pkg[0..1]}/#{pkg}/#{pkg}.tar.gz"
tarball	= "#{aurdir}/#{pkg}.tar.gz"
pkgdir	= "#{aurdir}/#{pkg}"

# Determine if a package directory with this name exists
if Dir.exists? pkgdir
  overwrite = ask("Overwrite existing directory #{pkgdir}? [y/N] ")
  if overwrite == true
    puts "Overwriting #{pkgdir}"
  else
    abort("ERROR: #{pkgdir} already exists.")
  end
end

# Download tarball
begin
  resp = open("#{tarDL}")
rescue OpenURI::HTTPError
  abort("ERROR: #{tarDL}\n#{$!}")
end

# Write response after handling possible HTTP error
File.open(tarball, 'wb') {|f| f.write resp.read}

# Extract
tgz = Zlib::GzipReader.new(File.open(tarball, 'rb'))
untar tgz, aurdir

# Build
Dir.chdir pkgdir
unless system 'makepkg -sif'
  abort("ERROR: makepkg failed. #{pkg} was not installed.")
end

# Cleanup
File.delete tarball
puts "Installed #{pkg}"
