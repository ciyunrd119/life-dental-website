require 'cgi'
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
  CANONICAL_TAG = /^[ \t]*<link\b[^>]*\brel=["']canonical["'][^>]*>\s*/i
  ROBOTS_TAG = /^[ \t]*<meta\b[^>]*\bname=["']robots["'][^>]*>\s*/i
  INDEX_TARGET_DIRECTORIES = {
    'index.html' => '.',
    'taichung/index.html' => 'taichung',
    'zhushan/index.html' => 'zhushan'
  }.freeze
  HREF_ATTRIBUTE = /(\bhref=)(["'])([^"']+)\2/i
  NON_LOCAL_HREF = %r{\A(?:[a-z][a-z0-9+.-]*:|//|#)}i

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

  def sync_canonical(html, canonical_url)
    raise 'HTML is missing </head>' unless html.match?(%r{</head>}i)
    raise 'HTML has duplicate canonical tags' if html.scan(CANONICAL_TAG).length > 1

    tag = %(  <link rel="canonical" href="#{CGI.escapeHTML(canonical_url)}">\n)
    if html.match?(CANONICAL_TAG)
      html.sub(CANONICAL_TAG, tag)
    else
      html.sub(%r{</head>}i, "#{tag}</head>")
    end
  end

  def sync_element_robots(html)
    raise 'element.html is missing </head>' unless html.match?(%r{</head>}i)
    raise 'element.html has duplicate robots tags' if html.scan(ROBOTS_TAG).length > 1

    html = html.gsub(CANONICAL_TAG, '')
    tag = %(  <meta name="robots" content="noindex, nofollow">\n)
    if html.match?(ROBOTS_TAG)
      html.sub(ROBOTS_TAG, tag)
    else
      html.sub(%r{</head>}i, "#{tag}</head>")
    end
  end

  def render_sitemap(urls)
    entries = urls.sort.map { |url| "  <url><loc>#{CGI.escapeHTML(url)}</loc></url>" }
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
      #{entries.join("\n")}
      </urlset>
    XML
  end

  def render_robots
    "User-agent: *\nAllow: /\n\nSitemap: #{ORIGIN}/sitemap.xml\n"
  end

  def normalize_index_links(html, document_path)
    document_directory = Pathname.new(File.dirname(document_path))

    html.gsub(HREF_ATTRIBUTE) do |attribute|
      prefix, quote, href = Regexp.last_match.captures
      next attribute if href.match?(NON_LOCAL_HREF)

      path, suffix = href.split(/(?=[?#])/, 2)
      root_relative = path.start_with?('/')
      resolved = if root_relative
                   path.delete_prefix('/')
                 else
                   document_directory.join(path).cleanpath.to_s
                 end
      target_directory = INDEX_TARGET_DIRECTORIES[resolved]
      next attribute unless target_directory

      normalized_path = if root_relative
                          target_directory == '.' ? '/' : "/#{target_directory}/"
                        else
                          relative = Pathname.new(target_directory)
                                             .relative_path_from(document_directory).to_s
                          relative == '.' ? './' : "#{relative}/"
                        end
      "#{prefix}#{quote}#{normalized_path}#{suffix}#{quote}"
    end
  end

  def sync(root, write:)
    desired = {}

    public_html_paths(root).each do |relative_path|
      absolute_path = File.join(root, relative_path)
      html = File.read(absolute_path)
      html = normalize_index_links(html, relative_path)
      desired[relative_path] = sync_canonical(html, canonical_url(relative_path))
    end

    desired['element.html'] = sync_element_robots(File.read(File.join(root, 'element.html')))
    urls = public_html_paths(root).map { |path| canonical_url(path) }
    desired['sitemap.xml'] = render_sitemap(urls)
    desired['robots.txt'] = render_robots

    changed = desired.each_with_object([]) do |(relative_path, content), paths|
      absolute_path = File.join(root, relative_path)
      current = File.exist?(absolute_path) ? File.read(absolute_path) : nil
      next if current == content

      File.write(absolute_path, content) if write
      paths << relative_path
    end

    changed.sort
  end
end

if $PROGRAM_NAME == __FILE__
  root = File.expand_path('..', __dir__)
  mode = ARGV.fetch(0, '--check')
  abort 'usage: --write or --check' unless %w[--write --check].include?(mode)

  changed = SeoMetadata.sync(root, write: mode == '--write')
  if mode == '--check' && !changed.empty?
    warn "SEO files need synchronization: #{changed.join(', ')}"
    exit 1
  end
end
