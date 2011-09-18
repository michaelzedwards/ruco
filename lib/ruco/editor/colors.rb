module Ruco
  class Editor
    module Colors
      RECOLORING_TIMEOUT = 2 # seconds
      INSTANT_RECOLORING_RANGE = 1 # recolor x lines around the current one
      DEFAULT_THEME = 'spec/fixtures/test.tmTheme'

      def style_map
        map = super

        # add colors to style map
        colorize(map, styled_lines[@window.visible_lines])
        if @selection
          # add selection a second time so it stays on top
          @window.add_selection_styles(map, @selection)
        end
        map
      end

      private

      def styled_lines
        # initially color everything
        @@styled_lines ||= parse_lines
        @@last_recoloring ||= Time.now.to_f

        current_time = Time.now.to_f
        if @@last_recoloring + RECOLORING_TIMEOUT < current_time
          # re-color everything max every 2 seconds
          @@styled_lines = parse_lines
          @@last_recoloring = Time.now.to_f
        else
          # re-color the current + 2 surrounding lines (in case of line changes)
          recolor = [line - INSTANT_RECOLORING_RANGE, 0].max..(line + INSTANT_RECOLORING_RANGE)
          parsed = parse_lines(recolor)
          recolor.to_a.size.times{|i| parsed[i] ||= [] } # for empty lines [] => [[],[],[]]
          @@styled_lines[recolor] = parsed
        end

        @@styled_lines
      end

      def parse_lines(range=nil)
        if language = @options[:language]
          parsed_lines = (range ? lines[range] : lines)
          SyntaxParser.parse_lines(parsed_lines, [language.name.downcase, language.lexer])
        else
          []
        end
      end

      def colorize(map, styled_lines)
        return unless styled_lines

        styled_lines.each_with_index do |style_positions, line|
          next unless style_positions
          style_positions.each do |syntax_element, columns|
            columns = columns.move(-@window.left)
            style = style_for_element(syntax_element)
            if style and columns.first >= 0
              map.add(style, line, columns)
            end
          end
        end
      end

      def style_for_element(syntax_element)
        @theme ||= Ruco::TMTheme.new(theme_file)
        @style_for_element ||= {}
        @style_for_element[syntax_element] ||= begin
          _, style = @theme.styles.detect{|name,style| syntax_element.start_with?(name) }
          style
        end
      end

      def theme_file
        file = download_into_file(@options[:color_theme]) if @options[:color_theme]
        file || DEFAULT_THEME
      end

      def download_into_file(url)
        theme_store = FileStore.new(File.expand_path('~/.ruco/themes'), :keep => 5, :pure => true)
        theme_store.cache(url) do
          require 'open-uri'
          require 'openssl'
          OpenURI.without_ssl_verification do
            open(url).read
          end
        end
        File.expand_path(theme_store.file(url))
      rescue => e
        STDERR.puts "Could not download #{url} -- #{e}"
      end
    end
  end
end