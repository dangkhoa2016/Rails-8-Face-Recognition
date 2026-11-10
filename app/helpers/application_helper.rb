module ApplicationHelper
  # Exact-source copy catalog. Locale-specific translations live in YAML and
  # are never machine-generated in a request. English remains the fallback.
  def ui(english)
    # I18n translates YAML keys into symbols, including keys with spaces.
    I18n.t("ui", default: {}).fetch(english.to_s.to_sym, english.to_s)
  end

  def nav_link(label, path, icon: nil, active: nil)
    # Nested routes normally inherit their parent's navigation highlight.
    # Explicit overrides keep sibling actions with overlapping URL prefixes
    # (e.g. /recognition/new and /recognition) mutually exclusive.
    if active.nil?
      exact_only = [root_path, admin_root_path].include?(path)
      active = current_page?(path) || (!exact_only && request.path.start_with?("#{path}/"))
    end
    classes = active ? "nav-link nav-link-active" : "nav-link"
    link_to(path, class: classes, "aria-current": (active ? "page" : nil)) do
      safe_join([icon && content_tag(:span, icon, class: "text-lg opacity-80", "aria-hidden": true), label].compact, " ")
    end
  end

  def status_badge(status)
    palette = case status.to_s
    when "ready", "completed", "approved", "matched" then "badge-success"
    when "pending", "preparing", "processing", "verifying", "importing", "draft" then "badge-info"
    when "error", "failed", "retired" then "badge-danger"
    when "unknown", "indeterminate", "not_calibrated", "deprecated" then "badge-warning"
    else "badge-neutral"
    end
    label = I18n.t("status.#{status}", default: status.to_s.humanize)
    content_tag(:span, class: "badge #{palette} whitespace-nowrap") do
      safe_join([content_tag(:span, "", class: "size-1.5 shrink-0 rounded-full bg-current opacity-75", "aria-hidden": true), label])
    end
  end

  def short_sha(value, length: 12)
    value.present? ? "#{value.first(length)}…" : "—"
  end

  def short_time(time)
    time ? l(time, format: :short) : "—"
  end

  def card_metric(value, label, supporting = nil)
    render "shared/metric", value: value, label: label, supporting: supporting
  end

  def safe_image_url(image)
    face_image_path(image) if image&.image&.attached?
  end
end
