#!/usr/bin/env ruby
# raur
# A simple AUR helper in Ruby
# by Boohbah <boohbah at gmail.com>
# Depends on pacman, makepkg, sudo, and the minitar gem

aurdir = "/home/user/aur" # Change this

require 'archive/tar/minitar'
require 'io/console'
require 'open-uri'

# Colors
red   = "\e[1;31m"
green = "\e[0;32m"
white = "\e[1;37m"
plain = "\e[0;0m"

error = "#{red}==> ERROR: #{white}"
info  = "#{green}==> #{white}"

pkg = ARGV.first

if pkg.nil?
  puts error + "No argument given. Specify the AUR package you want to build."
  puts info + "USAGE: raur pkgname" + plain
  exit
end

# Check for required executables
%w(/usr/bin/pacman /usr/bin/makepkg /usr/bin/sudo).each do |file|
  unless File.executable? file
    puts error + "#{file} does not exist or is not executable." + plain
    exit
  end
end

unless File.writable? aurdir
  puts error + "Directory #{aurdir} does not exist or is not writable." + plain
  exit
end

pkgdir = "#{aurdir}/#{pkg}"

# Determine if a package directory with this name exists
if File.directory? pkgdir
  print info + "Remove existing directory #{pkgdir} ? [y/n] " + plain
  puts input = STDIN.getch
  case input
  when 'y', 'Y'
    puts info + "Removing #{pkgdir}" + plain
    FileUtils.rm_rf pkgdir
  else
    print info + "Continue building #{pkg} ? [y/n] " + plain
    puts input = STDIN.getch
    case input
    when 'y', 'Y'
      puts info + "Writing over existing #{pkgdir}" + plain
    else
      exit
    end
  end
end

url = "https://aur.archlinux.org/packages/#{pkg[0..1]}/#{pkg}/#{pkg}.tar.gz"
tarball = "#{aurdir}/#{pkg}.tar.gz"

# Download tarball
begin
  File.open(tarball, 'wb') {|f| f.write open(url).read }
rescue OpenURI::HTTPError
  puts error + $!.to_s + plain
  puts url
  exit
rescue
  puts error + $!.to_s + plain
  exit
end


# Extract
begin
  tgz = Zlib::GzipReader.new(File.open(tarball, 'rb'))
  Archive::Tar::Minitar.unpack(tgz, aurdir)
rescue
  puts error + $!.to_s + plain
  exit
end

# Build
Dir.chdir(pkgdir)
system 'makepkg -sf'

unless $?.to_i.zero?
  puts error + "makepkg failed." + plain
  exit
end

# Sort files in package directory chronologically
files = Dir.entries(pkgdir).sort_by {|f| File.mtime(File.join(pkgdir, f)) }

# Find the first pkg.tar.xz file in the list
pkgfile = nil
files.map do |f|
  pkgfile = f.match(/.*.pkg.tar.xz/)
  break unless pkgfile.nil?
end

# Install
# TODO: Add --noconfirm option
system "sudo pacman -U #{pkgfile}"

unless $?.to_i.zero?
  puts error + "Failed to install #{pkgfile}" + plain
  exit
end

# Cleanup
begin
  File.delete(tarball)
rescue
  puts error + $!.to_s + plain
  exit
end

puts info + "Installed #{pkg}" + plain
