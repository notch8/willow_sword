# frozen_string_literal: true

require 'rails_helper'
require 'tmpdir'

RSpec.describe WillowSword::V2::WorksController, type: :controller do
  describe '#reject_symlinks! (zip symlink file-disclosure guard)' do
    around do |example|
      Dir.mktmpdir { |d| @dir = d; example.run }
    end

    it 'rejects the deposit (422) when an extracted archive contains a symlink' do
      File.write(File.join(@dir, 'ok.txt'), 'fine')
      File.symlink('/etc/passwd', File.join(@dir, 'exfil.txt'))

      expect { controller.send(:reject_symlinks!, @dir) }
        .to raise_error(WillowSword::SwordError) { |e| expect(e.sword_error.code).to eq(422) }
      # @error must be set: the works controller's local rescue only keeps the
      # 422 status when @error is already present, else it defaults to 400.
      expect(controller.instance_variable_get(:@error).code).to eq(422)
    end

    it 'detects a symlink nested in a real subdirectory' do
      Dir.mkdir(File.join(@dir, 'sub'))
      File.symlink('/etc/passwd', File.join(@dir, 'sub', 'exfil.txt'))

      expect { controller.send(:reject_symlinks!, @dir) }.to raise_error(StandardError)
    end

    it 'does not descend into a symlinked directory (detects it, does not follow)' do
      File.symlink('/etc', File.join(@dir, 'evil'))
      # returns the symlink itself; must not raise SystemStackError from recursing into /etc
      expect(controller.send(:find_symlink, @dir)).to eq(File.join(@dir, 'evil'))
    end

    it 'passes cleanly when no symlinks are present' do
      File.write(File.join(@dir, 'a.txt'), 'x')
      Dir.mkdir(File.join(@dir, 'sub'))
      File.write(File.join(@dir, 'sub', 'b.txt'), 'y')

      expect { controller.send(:reject_symlinks!, @dir) }.not_to raise_error
      expect(controller.instance_variable_get(:@error)).to be_nil
    end
  end
  describe '#fetch_data (binary request body)' do
    # Behaves like a rack input: #each yields up to the next newline, so a body
    # with no newlines comes back as one string the size of the whole body.
    let(:body_class) do
      Class.new do
        attr_reader :largest_chunk

        def initialize(content)
          @io = StringIO.new(content)
          @largest_chunk = 0
        end

        def rewind
          @io.rewind
        end

        def read(length = nil, outbuf = nil)
          track(@io.read(length, outbuf))
        end

        def each
          while (line = @io.gets)
            yield track(line)
          end
        end

        private

        def track(chunk)
          @largest_chunk = [@largest_chunk, chunk.bytesize].max if chunk
          chunk
        end
      end
    end
    let(:content) { 'a' * 8.megabytes }
    let(:body) { body_class.new(content) }

    let(:dir) { Dir.mktmpdir }

    before do
      controller.instance_variable_set(:@dir, dir)
      controller.instance_variable_set(:@headers, { filename: 'payload.bin' })
    end

    after { FileUtils.rm_rf(dir) }

    it 'copies a body without newlines to disk in bounded chunks' do
      path = controller.send(:fetch_data, body, 'binary', false)

      expect(File.size(path)).to eq(content.bytesize)
      expect(body.largest_chunk).to be <= 1.megabyte
    end
  end
end
