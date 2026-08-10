# frozen_string_literal: true

require 'rails_helper'

# Exercised through a controller that includes the FetchHeaders concern.
RSpec.describe WillowSword::V2::WorksController, type: :controller do
  describe '#fetch_filename (Content-Disposition sanitization)' do
    def filename_for(cd)
      controller.request.headers['Content-Disposition'] = cd
      controller.instance_variable_set(:@headers, {})
      controller.send(:fetch_filename)
      controller.instance_variable_get(:@headers)[:filename]
    end

    it 'strips path separators from an injection-style payload' do
      name = filename_for('attachment; filename=x"; touch /tmp/pwned; echo "')
      expect(name).not_to match(%r{[/\\]})
    end

    it 'prevents path traversal' do
      expect(filename_for('attachment; filename="../../../../etc/passwd"')).to eq('passwd')
      expect(filename_for('attachment; filename="..\\..\\windows\\x"')).not_to match(%r{[/\\]})
    end

    it 'preserves spaces and unicode in the filename' do
      expect(filename_for('attachment; filename="my report.pdf"')).to eq('my report.pdf')
      expect(filename_for('attachment; filename="café.pdf"')).to eq('café.pdf')
    end

    it 'keeps a quoted filename containing "=" intact (old split truncated it)' do
      expect(filename_for('attachment; filename="a=b.pdf"')).to eq('a=b.pdf')
    end

    it 'ignores trailing non-filename parameters' do
      expect(filename_for('attachment; filename="report.pdf"; foo=bar')).to eq('report.pdf')
    end

    it 'does not treat filename*= inside a quoted value as the extended param' do
      expect(filename_for('attachment; filename="notes filename*=draft.pdf"')).to eq('notes filename*=draft.pdf')
    end

    it 'matches parameter names exactly (xfilename* is not filename*)' do
      expect(filename_for('attachment; xfilename*=draft.pdf')).to match(/\A[0-9a-f-]{36}\z/)
    end

    it 'prefers and percent-decodes filename* (RFC 5987/6266)' do
      expect(filename_for("attachment; filename*=UTF-8''%e2%82%ac%20rates.pdf")).to eq('€ rates.pdf')
    end

    it 'decodes filename* with a non-empty language tag' do
      expect(filename_for("attachment; filename*=UTF-8'en'%E2%82%AC.pdf")).to eq('€.pdf')
    end

    it 'does not leave a path separator from a slash-only filename' do
      expect(filename_for('attachment; filename="/"')).not_to match(%r{[/\\]})
    end

    it 'handles a raw ASCII-8BIT filename with high bytes without raising' do
      # Rack delivers header values as ASCII-8BIT; a UTF-8 regex against those
      # bytes raised Encoding::CompatibilityError before the force_encoding fix.
      raw = 'café.pdf'.dup.force_encoding('ASCII-8BIT')
      expect(controller.send(:sanitize_filename, raw)).to eq('café.pdf')
    end

    it 'matches the parameter name case-insensitively' do
      expect(filename_for('attachment; FileName="Doc.pdf"')).to eq('Doc.pdf')
    end

    it 'falls back to a UUID when no filename is present' do
      expect(filename_for('attachment')).to match(/\A[0-9a-f-]{36}\z/)
      expect(filename_for('')).to match(/\A[0-9a-f-]{36}\z/)
    end

    it 'falls back to a UUID when sanitization leaves nothing usable' do
      expect(filename_for('attachment; filename="../"')).to match(/\A[0-9a-f-]{36}\z/)
    end

    it 'does not raise on invalid UTF-8 bytes from a decoded filename*' do
      # regression: strip ran before scrub and raised ArgumentError -> unauthenticated 500
      expect { filename_for("attachment; filename*=UTF-8''%ff%fe.txt") }.not_to raise_error
    end
  end
end
