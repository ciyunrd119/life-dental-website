require 'pathname'

module SeoMetadata
  ORIGIN = 'https://www.gracelife.com.tw'.freeze
  ROOT_PAGES = %w[
    appointment.html
    idea.html
    index.html
    knowledge.html
    news.html
    offday.html
    videos.html
  ].freeze
  PUBLIC_DIRECTORIES = %w[cases knowledge services taichung zhushan].freeze

  module_function

  def public_html_paths(root)
    directory_pages = PUBLIC_DIRECTORIES.flat_map do |directory|
      Dir.glob(File.join(root, directory, '**', '*.html')).map do |absolute_path|
        Pathname.new(absolute_path).relative_path_from(Pathname.new(root)).to_s
      end
    end
    (ROOT_PAGES + directory_pages).sort
  end

  def canonical_url(path)
    segments = path.split('/')
    public_path = !segments.any? { |segment| segment == '.' || segment == '..' } &&
                  (ROOT_PAGES.include?(path) || PUBLIC_DIRECTORIES.any? do |directory|
                    path.match?(%r{\A#{Regexp.escape(directory)}/.+\.html\z})
                  end)
    raise ArgumentError, "not a public HTML path: #{path}" unless public_path

    canonical_path = case path
                     when 'index.html' then '/'
                     when 'taichung/index.html' then '/taichung/'
                     when 'zhushan/index.html' then '/zhushan/'
                     else "/#{path}"
                     end
    "#{ORIGIN}#{canonical_path}"
  end
end
