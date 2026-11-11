require "application_system_test_case"

class BrowserFlowsTest < ApplicationSystemTestCase
  setup do
    # Selenium may reuse its window between randomized system tests.
    page.driver.browser.manage.window.resize_to(1440, 900)
  end

  test "visitor can switch between English and Vietnamese and change the theme" do
    visit root_path
    assert_selector "html[lang='en'][data-theme='auto']", visible: :all

    page.execute_script("window.__themeNavigationMarker = 'still-here'")
    find("select[name='theme']").select("Dark")
    assert_selector "html[lang='en'][data-theme='dark']", visible: :all
    assert_equal "still-here", page.evaluate_script("window.__themeNavigationMarker"),
      "Theme selection must not navigate or reload the browser"

    find("select[name='locale']").select("Tiếng Việt")
    assert_selector "html[lang='vi'][data-theme='dark']", visible: :all

    find("select[name='theme']").select("Theo hệ thống")
    assert_selector "html[lang='vi'][data-theme='auto']", visible: :all
  end

  test "mobile navigation toggles and exposes its expanded state" do
    page.driver.browser.manage.window.resize_to(390, 844)
    visit root_path

    button = find("button[aria-controls='mobile-navigation']")
    assert button.visible?
    assert_equal "false", button["aria-expanded"]

    button.click
    assert_selector "#mobile-navigation:not(.hidden)", visible: :all
    assert_equal "true", button["aria-expanded"]
  end

  test "verified member signs in and reaches the sample gallery" do
    user = User.create!(email: "browser-member@example.org", role: "member",
      email_verified_at: Time.current, password: "strong-browser-password-789")
    visit sign_in_path
    fill_in "Email address", with: user.email
    fill_in "Password", with: "strong-browser-password-789"
    click_button "Sign in"

    assert_current_path samples_path
    assert_selector "a[href='#{samples_path}']", text: "Sample gallery"
  end

  test "locale change keeps the administrator on the same nested URL" do
    user = User.create!(email: "locale-admin@example.org", role: "admin",
      email_verified_at: Time.current, password: "strong-browser-password-789")
    visit sign_in_path
    fill_in "Email address", with: user.email
    fill_in "Password", with: "strong-browser-password-789"
    click_button "Sign in"
    assert_current_path admin_root_path

    visit admin_dataset_imports_path
    assert_current_path admin_dataset_imports_path
    find("select[name='locale']").select("Tiếng Việt")
    assert_selector "html[lang='vi']", visible: :all
    assert_current_path admin_dataset_imports_path
    assert_selector "aside nav a[aria-current='page']", count: 1
    assert_selector "aside nav a[href='#{admin_dataset_imports_path}']", text: "Nhập bộ dữ liệu"
  end

  test "dataset import status badge remains compact at desktop and mobile widths" do
    user = User.create!(email: "badge-admin@example.org", role: "admin",
      email_verified_at: Time.current, password: "strong-browser-password-789")
    import = DatasetImport.create!(source_name: "CompactFaces Synthetic Face Dataset",
      source_url: "https://example.org/datasets/compactfaces", dataset_version: "1.0.0",
      import_status: "pending")

    visit sign_in_path
    fill_in "Email address", with: user.email
    fill_in "Password", with: "strong-browser-password-789"
    click_button "Sign in"
    assert_current_path admin_root_path
    visit admin_dataset_import_path(import)
    assert_current_path admin_dataset_import_path(import)
    assert_selector "main span.badge-info", visible: :all

    [[1440, 900], [390, 844]].each do |width, height|
      page.driver.browser.manage.window.resize_to(width, height)
      badge = find("main span.badge-info")
      assert badge.visible?
      dimensions = page.evaluate_script(<<~JS)
        (() => {
          const rect = document.querySelector('main span.badge-info').getBoundingClientRect();
          return { width: rect.width, height: rect.height };
        })()
      JS
      assert_operator dimensions.fetch("height"), :<, 42,
        "Dataset status badge should not stretch vertically at #{width}px"
      assert_operator dimensions.fetch("width"), :>, dimensions.fetch("height"),
        "Dataset status badge should remain a horizontal pill at #{width}px"
    end
  end

  test "visitor can submit an email registration using the visible form" do
    visit new_registration_path
    assert_selector "form[action='#{registration_path}']"

    fill_in "Email address", with: "browser-signup@example.org"
    fill_in "Password", with: "strong-browser-password-789"
    fill_in "Confirm password", with: "strong-browser-password-789"
    find("input[name='accept_terms']").check
    click_button "Register and send verification"

    assert_current_path sign_in_path
    assert User.exists?(email: "browser-signup@example.org", role: "member", email_verified_at: nil)
  end
end
