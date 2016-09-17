module Jekyll
  class SpoilerTag < Liquid::Block

    def initialize(tag_name, markup, tokens)
      super
      @header = markup.strip
    end

    def render(context)
      require 'securerandom'
      id = SecureRandom.uuid

      site = context.registers[:site]
      converter = site.find_converter_instance(Jekyll::Converters::Markdown)

      content = super
      content = converter.convert(content)

      '<div class="spoiler">'\
      "    <input type=\"checkbox\" id=\"#{id}\"><label for=\"#{id}\">"\
      "    #{@header}"\
      '    </label>'\
      '    <div class="spoiler_body">' +
        content +
      '    </div>'\
      '</div>'
    end
  end
end

Liquid::Template.register_tag('spoiler', Jekyll::SpoilerTag)
