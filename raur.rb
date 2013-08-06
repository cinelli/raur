#!/usr/bin/env ruby
#
# raur
# A simple AUR helper in Ruby
# Depends on pacman, makepkg, sudo, and the minitar gem
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

require 'archive/tar/minitar'
require 'io/console'
require 'open-uri'

# Colors
RED   = "\e[1;31m"
GREEN = "\e[0;32m"
WHITE = "\e[1;37m"
RC = "\e[0m"

ERROR = "#{RED}==> ERROR: #{WHITE}"
INFO  = "#{GREEN}==> #{WHITE}"

def info s
  print INFO + s + RC
end

begin
  pkg = ARGV.first

  if pkg.nil?
    raise "No argument given. Specify the AUR package you want to build.\n" +
          "#{INFO}Usage: raur pkgname"
  end

  # Check for required executables
  %w(/usr/bin/pacman /usr/bin/makepkg /usr/bin/sudo).each do |file|
    unless File.executable? file
      raise "#{file} does not exist or is not executable."
    end
  end

  #unless File.writable? aurdir
  #  raise "Directory #{aurdir} does not exist or is not writable."
  #end

  pkgdir = "#{aurdir}/#{pkg}"

  # Determine if a package directory with this name exists
  if File.directory? pkgdir
    info "Remove existing directory #{pkgdir} ? [y/N] "
    puts input = STDIN.getch
    case input
    when 'y', 'Y'
      info "Removing #{pkgdir}\n"
      FileUtils.rm_rf pkgdir
    else
      info "Continue building #{pkg} ? [Y/n] "
      puts input = STDIN.getch
      case input
      when 'y', 'Y', "\r"
        info "Writing over existing #{pkgdir}\n"
      else
        exit
      end
    end
  end

  url = "https://aur.archlinux.org/packages/#{pkg[0..1]}/#{pkg}/#{pkg}.tar.gz"
  tarball = "#{aurdir}/#{pkg}.tar.gz"

  # Download tarball
  File.open(tarball, 'wb') {|f| f.write open(url).read }

  # Extract
  tgz = Zlib::GzipReader.new(File.open(tarball, 'rb'))
  Archive::Tar::Minitar.unpack(tgz, aurdir)

  # Build
  Dir.chdir(pkgdir)
  raise "makepkg failed." unless system "makepkg -sf"

  # Find newest file
  pkgfile = Dir.entries(pkgdir).sort_by {|f|
    File.mtime(File.join(pkgdir,f))
  }.last

  # Install
  raise "Failed to install #{pkgfile}" unless system "sudo pacman -U #{pkgfile}"

  # Cleanup
  File.delete(tarball)

  info "Installed #{pkg}\n"

rescue OpenURI::HTTPError
  puts "#{ERROR}#{$!}#{RC}\n#{url}"
rescue
  puts "#{ERROR}#{$!}#{RC}"
end
