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
end
