require 'minitest/autorun'

class ServiceHeroImageTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  PAGES = %w[
    services/all-ceramic-crown.html
    services/all-on-4.html
    services/zygoma-implant.html
  ].freeze

  def test_full_arch_treatment_hero_images_exist
    PAGES.each do |page|
      page_path = File.join(ROOT, page)
      html = File.read(page_path)
      image_src = html.match(%r{<div class="hero-image-area">\s*<img src="([^"]+)"}m)&.captures&.first

      refute_nil image_src, "#{page} 缺少療程主視覺"
      image_path = File.expand_path(image_src, File.dirname(page_path))
      assert File.file?(image_path), "#{page} 的療程主視覺不存在：#{image_src}"
    end
  end
end
