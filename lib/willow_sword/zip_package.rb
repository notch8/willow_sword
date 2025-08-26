require 'zip'

module WillowSword
  class ZipPackage
    # Class to unzip a file and create a zip file

    attr_reader :dst

    def initialize(src, dst)
      @src = src
      @dst = dst
      @src = File.join(src, '/') if File.directory?(src)
      @dst = File.join(dst, '/') if File.directory?(dst)
    end

    # Unpack a zip file along with any folders and sub folders at the destination
    def unzip_file
      Zip::File.open(@src) { |zip_file|
        zip_file.each { |f|
          f_path=File.join(@dst, f.name)
          FileUtils.mkdir_p(File.dirname(f_path))
          zip_file.extract(f, f_path) unless File.exist?(f_path)
        }
      }
    end

    # Recursively generate a zip file from the contents of a specified directory.
    # The directory itself is not included in the archive, rather just its contents.
    def create_zip
      entries = Dir.entries(@src); entries.delete("."); entries.delete("..")
      io = Zip::File.open(@dst, Zip::File::CREATE)
      writeEntries(entries, "", io)
      io.close()
    end

    private
    # A helper method to make the recursion work.
    def writeEntries(entries, path, io)
      entries.each { |e|
        zipFilePath = path == "" ? e : File.join(path, e)
        diskFilePath = File.join(@src, zipFilePath)
        if  File.directory?(diskFilePath)
          io.mkdir(zipFilePath)
          subdir =Dir.entries(diskFilePath); subdir.delete("."); subdir.delete("..")
          writeEntries(subdir, zipFilePath, io)
        else
          disk_file = File.open(diskFilePath, "rb")
          io.get_output_stream(zipFilePath) { |f| f.write(disk_file.read()) }
          disk_file.close
        end
      }
    end

  end
end
