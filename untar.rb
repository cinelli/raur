# https://gist.github.com/sinisterchipmunk/1335041

require 'rubygems/package'
require 'fileutils'

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
