require 'minitest/autorun'

class ZhushanPathTest < Minitest::Test
  def test_zhushan_directory_contains_all_clinic_pages
    expected_pages = %w[
      zhushan/index.html
      zhushan/team.html
      zhushan/medical-equipment.html
      zhushan/digital-implant-center.html
      zhushan/team/dr-chang-shih-shu.html
      zhushan/team/dr-chen-min-tso.html
      zhushan/team/dr-huang-rui-bin.html
      zhushan/team/dr-liu-chao-sheng.html
      zhushan/team/dr-ou-yang-guo-cai.html
      zhushan/team/dr-su-wan-ling.html
    ]

    missing_pages = expected_pages.reject { |page| File.file?(page) }

    assert_empty missing_pages, "zhushan 路徑缺少頁面: #{missing_pages.join(', ')}"
  end

  def test_site_pages_do_not_link_to_legacy_zushan_path
    site_files = Dir.glob('**/*.{html,css,js}').reject do |path|
      path.start_with?('docs/')
    end
    legacy_references = site_files.map do |path|
      path if File.read(path).match?(%r{(?:\.\./|/)?zushan/})
    end.compact

    assert_empty legacy_references,
                 "仍連向 zushan 舊路徑的檔案: #{legacy_references.join(', ')}"
  end
end
