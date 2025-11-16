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
      FileUtils.mkdir_p(@dst)
      Rails.logger.info "Extracting #{File.basename(@src)} to #{@dst}"
      cmd = ["unzip", "-q", @src, "-d", @dst]

      unless system(*cmd)
        error_msg = "Unzip failed with exit code #{$?.exitstatus}"
        Rails.logger.error error_msg
        @error = WillowSword::Error.new(error_msg, :unprocessable_entity)
        return false
      end
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
