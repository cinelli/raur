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

error_header = "#{red}==> ERROR: #{white}"
info_header = "#{green}==> #{white}"

pkg = ARGV.first

if pkg.nil?
  print error_header
  puts "No argument given. Specify the AUR package you want to build."
  print info_header
  puts "USAGE: raur pkgname"
  print plain
  exit
end

# Check for required executables
%w(/usr/bin/pacman /usr/bin/makepkg /usr/bin/sudo).each do |file|
  unless File.executable? file
    print error_header
    puts "#{file} does not exist or is not executable."
    print plain
    exit
  end
end

unless File.writable? aurdir
  print error_header
  puts "Directory #{aurdir} does not exist or is not writable."
  print plain
  exit
end

pkgdir = "#{aurdir}/#{pkg}"

# Determine if a package directory with this name exists
if File.directory? pkgdir
  print info_header
  print "Remove existing directory #{pkgdir} ? [y/n] "
  print plain
  puts input = STDIN.getch
  case input
  when 'y', 'Y'
    print info_header
    puts "Removing #{pkgdir}"
    print plain
    FileUtils.rm_rf pkgdir
  else
    print info_header
    print "Continue building #{pkg} ? [y/n] "
    print plain
    puts input = STDIN.getch
    case input
    when 'y', 'Y'
      print info_header
      puts "Writing over existing #{pkgdir}"
      print plain
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
  print error_header
  puts $!
  puts plain + url
  exit
rescue
  print error_header
  puts $! + plain
  exit
end


# Extract
begin
  tgz = Zlib::GzipReader.new(File.open(tarball, 'rb'))
  Archive::Tar::Minitar.unpack(tgz, aurdir)
rescue
  print error_header
  puts $! + plain
  exit
end

# Build
Dir.chdir(pkgdir)
unless `makepkg -sf`
  print error_header
  puts "makepkg failed."
  print plain
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
puts exit_status = `sudo pacman -U --noconfirm #{pkgfile}`
unless exit_status.to_i.zero?
  print error_header
  puts "Failed to install #{pkgfile}"
  print plain
  exit
end

# Cleanup
begin
  File.delete(tarball)
rescue
  print error_header
  puts $! + plain
  exit
end

print info_header
puts "Installed #{pkg}"
print plain
