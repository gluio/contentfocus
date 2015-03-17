module Nesta
  class Page < FileModel
    def intro_image
      return metadata('intro image') if metadata('intro image')
      if self.parent
        image = Dir["#{File.dirname(__FILE__)}/public/median/images/cover*.jpg"].sample
        path = image.match("(/images/.*jpg)")[0]
        "/median#{path}"
      end
    end
  end

  class App
    use Rack::Static, urls: ["/median/"], root: "themes/median/public"
    helpers do
      def format_date(date)
        date.strftime("%d %b %Y")
      end

      def reading_time(content)
        words_per_minute = 270
        words = content.split.size
        minutes = words.to_f/words_per_minute.to_f
        if minutes < 2
          "1 min"
        else
          "#{minutes.to_i} min"
        end
      end

      def strip_html(content)
        content.gsub(/<.+?>/, " ")
      end

      def generate_summary(content)
        summary = strip_html(content).match(/(.*?\.){,2}/)[0]
        return summary if summary == content
        summary.sub(/\.\z/,"&hellip;")
      end

      def author_biography(name = nil)
        name ||= @page.metadata('author')
        if name
          template = name.downcase.gsub(/\W+/, '-')
          page = Page.find_by_path("/#{template}")
          page.body
        end
      end

      def author_url(name)
        "/#{name.downcase.gsub(/\W+/, '-')}"
      end
    end
  end
end
