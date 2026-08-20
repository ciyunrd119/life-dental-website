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
end
