require 'fileutils'
require 'securerandom'

module WillowSword
  module FetchHeaders

    private

    def fetch_headers
      @headers = {}
      fetch_content_type
      fetch_filename
      fetch_md5hash
      fetch_packaging
      fetch_in_progress
      fetch_on_behalf_of
      fetch_slug
      fetch_hyrax_work_model
      fetch_api_key
      fetch_content_range
    end

    def fetch_content_type
      @headers[:content_type] = request.headers.fetch('Content-Type', nil)
    end

    def fetch_filename
      cd = request.headers.fetch('Content-Disposition', '')
      @headers[:filename] = sanitize_filename(extract_cd_filename(cd))
    end

    # Prefers RFC 5987/6266 filename* over filename, matching parameter names
    # exactly (case-insensitive) and respecting quoted-string boundaries so a
    # filename*= inside a quoted value or a name like xfilename* can't win.
    # RFC 2231 continuations (filename*0, filename*1) are not reassembled.
    def extract_cd_filename(cd)
      return nil if cd.blank?
      params = {}
      cd.scan(/(?:\A|;)\s*([^\s=;]+)\s*=\s*("(?:[^"\\]|\\.)*"|[^;]*)/) do |name, val|
        val = val.start_with?('"') ? val[1..-2].gsub(/\\(.)/, '\1') : val.strip
        params[name.downcase] ||= val
      end
      if params.key?('filename*')
        decode_ext_value(params['filename*'])
      elsif params.key?('filename')
        params['filename']
      end
    end

    # RFC 5987 ext-value: charset'lang'percent-encoded-value
    def decode_ext_value(val)
      charset, _lang, encoded = val.split("'", 3)
      encoded ||= charset # no charset'lang' prefix; treat whole thing as value
      bytes = encoded.gsub(/%([0-9a-fA-F]{2})/) { $1.hex.chr }
      src = charset.to_s.casecmp?('iso-8859-1') ? Encoding::ISO_8859_1 : Encoding::UTF_8
      bytes.force_encoding(src).encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
    end

    # Blocks path traversal and control/bidi chars. Spaces, unicode, and shell
    # metacharacters are preserved and safe only because nothing shells out with
    # this value (see validate_payload, get_content_type) - keep it that way.
    def sanitize_filename(name)
      # Header bytes arrive as ASCII-8BIT; tag as UTF-8 so the control/bidi
      # regex below is encoding-compatible, then scrub any invalid sequences.
      name = name.to_s.dup.force_encoding(Encoding::UTF_8).scrub('').strip
      name = name.gsub(/[\u0000-\u001f\u007f\u200e\u200f\u202a-\u202e\u2066-\u2069]/, %q())
      name = File.basename(name).tr('/\\', '_')
      return SecureRandom.uuid if name.blank? || name == '.' || name == '..'
      name
    end

    def fetch_md5hash
      @headers[:md5hash] = request.headers.fetch('Content-MD5', nil)
    end

    def fetch_packaging
      @headers[:packaging] = request.headers.fetch('Packaging', nil)
    end

    def fetch_in_progress
      @headers[:in_progress] = request.headers.fetch('In-Progress', nil)
    end

    def fetch_on_behalf_of
      @headers[:on_behalf_of] = request.headers.fetch('On-Behalf-Of', nil)
    end

    def fetch_slug
      @headers[:slug] = request.headers.fetch('Slug', nil)
    end

    # custom header for model HyraxWorkModel
    def fetch_hyrax_work_model
      model = request.headers.fetch('Hyrax-Work-Model', default_work_model)
      model = model.underscore.gsub('_', ' ').gsub('-', ' ').downcase unless model.blank?
      @headers[:hyrax_work_model] = model
    end

    def fetch_api_key
      @headers[:api_key] = request.headers.fetch('Api-key', nil)
    end

    def fetch_content_range
      @headers[:content_range] = request.headers.fetch('Content-Range', nil)
    end

    # Looks for the lazy migration convention if it exists
    def default_work_model
      model = WillowSword.config.default_work_model
      model = "#{model.to_s}Resource".safe_constantize || model
      model.to_s
    end
  end
end
