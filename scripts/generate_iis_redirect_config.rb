require 'cgi'
require 'yaml'

module IisRedirectConfig
  module_function

  def load_inventory(path)
    YAML.safe_load(File.read(path))
  end

  def expanded_redirects(inventory)
    same_date = inventory.fetch('same_date_knowledge').to_h do |date|
      ["/know_#{date}.html", "/knowledge/know_#{date}.html"]
    end
    inventory.fetch('fixed_redirects').merge(same_date).merge(inventory.fetch('renamed_knowledge'))
  end

  def render(inventory)
    rules = expanded_redirects(inventory).sort.map.with_index(1) do |(source, destination), index|
      <<~XML.chomp
              <rule name="Legacy 301 #{format('%03d', index)}" stopProcessing="true">
                <match url="^#{CGI.escapeHTML(Regexp.escape(source.delete_prefix('/')))}$" ignoreCase="true" />
                <action type="Redirect" url="#{CGI.escapeHTML(destination)}" redirectType="Permanent" appendQueryString="true" />
              </rule>
      XML
    end

    <<~XML
      <?xml version="1.0" encoding="utf-8"?>
      <configuration>
        <system.webServer>
          <rewrite>
            <rules>
      #{rules.join("\n")}
            </rules>
          </rewrite>
        </system.webServer>
      </configuration>
    XML
  end
end

if $PROGRAM_NAME == __FILE__
  root = File.expand_path('..', __dir__)
  inventory = IisRedirectConfig.load_inventory(File.join(root, 'config/iis_legacy_urls.yml'))
  output = IisRedirectConfig.render(inventory)
  if ARGV == ['--write']
    File.write(File.join(root, 'web.config'), output)
  else
    print output
  end
end
