require 'minitest/autorun'

class ServiceInteractionsTest < Minitest::Test
  SERVICE_PAGES = %w[
    services/3d-inlay.html
    services/all-ceramic-crown.html
    services/all-on-4.html
    services/ceramic-veneer.html
    services/gum-contouring.html
    services/implant-augmentation.html
    services/implant.html
    services/invisalign.html
    services/microscope-root-canal.html
    services/orthodontics.html
    services/periodontal-treatment.html
    services/teeth-whitening.html
    services/zirconia-crown.html
    services/zygoma-implant.html
  ].freeze

  def test_shared_service_interactions_live_in_main_js
    source = File.read('js/main.js')

    assert_includes source, 'Shared treatment page interactions'
    assert_includes source, "document.querySelectorAll('.reveal')"
    assert_includes source, "document.querySelectorAll('.process-step')"
    assert_includes source, "document.querySelectorAll('.faq-question')"
    assert_includes source, "document.querySelector('.ao4-team-grid')"
  end

  def test_service_pages_do_not_embed_inline_scripts
    SERVICE_PAGES.each do |page|
      refute_match(/<script>\s*.*?<\/script>/m, File.read(page), page)
    end
  end

  def test_implant_process_circles_show_icons_in_order
    source = File.read('services/implant.html')
    circles = source.scan(/<div class="step-circle">(.*?)<\/div>/m).flatten
    icon_sources = circles.map { |circle| circle[/<img class="[^"]*\bstep-icon\b[^"]*" src="([^"]+)"/, 1] }

    assert_equal %w[
      ../img/services/implant/icon-implant_1.svg
      ../img/services/implant/icon-implant_2.svg
      ../img/services/implant/icon-implant_3.svg
      ../img/services/implant/icon-implant_4.svg
      ../img/services/implant/icon-implant_5.svg
    ], icon_sources
  end

  def test_all_on_4_process_circles_show_icons_in_order
    source = File.read('services/all-on-4.html')
    circles = source.scan(/<div class="step-circle">(.*?)<\/div>/m).flatten
    icon_sources = circles.map { |circle| circle[/<img class="[^"]*\bstep-icon\b[^"]*" src="([^"]+)"/, 1] }

    assert_equal %w[
      ../img/services/allon4/icon-allon4_1.svg
      ../img/services/allon4/icon-allon4_2.svg
      ../img/services/allon4/icon-allon4_3.svg
      ../img/services/allon4/icon-allon4_4.svg
      ../img/services/allon4/icon-allon4_5.svg
    ], icon_sources
  end

  def test_zygoma_process_circles_show_icons_in_order
    source = File.read('services/zygoma-implant.html')
    circles = source.scan(/<div class="step-circle">(.*?)<\/div>/m).flatten
    icon_sources = circles.map { |circle| circle[/<img class="[^"]*\bstep-icon\b[^"]*" src="([^"]+)"/, 1] }

    assert_equal %w[
      ../img/services/zygoma/icon-zygoma_1.svg
      ../img/services/zygoma/icon-zygoma_2.svg
      ../img/services/zygoma/icon-zygoma_3.svg
      ../img/services/zygoma/icon-zygoma_4.svg
      ../img/services/zygoma/icon-zygoma_5.svg
    ], icon_sources
  end

  def test_invisalign_process_circles_show_icons_in_order
    source = File.read('services/invisalign.html')
    circles = source.scan(/<div class="step-circle">(.*?)<\/div>/m).flatten
    icon_sources = circles.map { |circle| circle[/<img class="[^"]*\bstep-icon\b[^"]*" src="([^"]+)"/, 1] }

    assert_equal %w[
      ../img/services/invisalign/icon-invisalign_1.svg
      ../img/services/invisalign/icon-invisalign_2.svg
      ../img/services/invisalign/icon-invisalign_3.svg
      ../img/services/invisalign/icon-invisalign_4.svg
      ../img/services/invisalign/icon-invisalign_5.svg
    ], icon_sources
  end

  def test_orthodontics_process_circles_show_icons_in_order
    source = File.read('services/orthodontics.html')
    circles = source.scan(/<div class="step-circle">(.*?)<\/div>/m).flatten
    icon_sources = circles.map { |circle| circle[/<img class="[^"]*\bstep-icon\b[^"]*" src="([^"]+)"/, 1] }

    assert_equal %w[
      ../img/services/ortho/icon-ortho_1.svg
      ../img/services/ortho/icon-ortho_2.svg
      ../img/services/ortho/icon-ortho_3.svg
      ../img/services/ortho/icon-ortho_4.svg
      ../img/services/ortho/icon-ortho_5.svg
    ], icon_sources
  end

  def test_periodontal_process_circles_show_icons_in_order
    source = File.read('services/periodontal-treatment.html')
    circles = source.scan(/<div class="step-circle">(.*?)<\/div>/m).flatten
    icon_sources = circles.map { |circle| circle[/<img class="[^"]*\bstep-icon\b[^"]*" src="([^"]+)"/, 1] }

    assert_equal %w[
      ../img/services/perio/icon-perio_1.svg
      ../img/services/perio/icon-perio_2.svg
      ../img/services/perio/icon-perio_3.svg
      ../img/services/perio/icon-perio_4.svg
      ../img/services/perio/icon-perio_5.svg
    ], icon_sources
  end

  def test_microscope_root_canal_process_circles_show_icons_in_order
    source = File.read('services/microscope-root-canal.html')
    circles = source.scan(/<div class="step-circle">(.*?)<\/div>/m).flatten
    icon_sources = circles.map { |circle| circle[/<img class="[^"]*\bstep-icon\b[^"]*" src="([^"]+)"/, 1] }

    assert_equal %w[
      ../img/services/microscope/icon-microscope_1.svg
      ../img/services/microscope/icon-microscope_2.svg
      ../img/services/microscope/icon-microscope_3.svg
      ../img/services/microscope/icon-microscope_4.svg
      ../img/services/microscope/icon-microscope_5.svg
    ], icon_sources
  end

  def test_service_process_icons_share_one_large_size
    css = File.read('css/style.css')

    assert_match(/\.ceramic-source-page \.step-icon \{ width: 81px; height: 81px;/, css)
    refute_includes css, 'implant-step-icon'
    SERVICE_PAGES.each do |page|
      refute_includes File.read(page), 'implant-step-icon', page
    end
  end
end
