module Nesta
  class Page < FileModel
    def intro_image
      return metadata('Intro Image') if metadata('Intro Image')
      if self.parent
        images = %w[
          https://dl.dropboxusercontent.com/u/2609971/cover001.jpg
          https://dl.dropboxusercontent.com/u/2609971/cover002.jpg
          https://dl.dropboxusercontent.com/u/2609971/cover003.jpg
          https://dl.dropboxusercontent.com/u/2609971/cover004.jpg
          https://dl.dropboxusercontent.com/u/2609971/cover005.jpg
          https://dl.dropboxusercontent.com/u/2609971/cover006.jpg
          https://dl.dropboxusercontent.com/u/2609971/cover007.jpg
        ]
        images.sample
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
