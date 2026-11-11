#!/usr/bin/env ruby
# Verify every published Markdown document has a corresponding EN/VI variant.
require "pathname"

root = Pathname.new(__dir__).parent
files = [root.join("README.md"), root.join("README.vi.md")]
files += Dir.glob(root.join("{docs,.github}/**/*.md"), File::FNM_EXTGLOB).map { |path| Pathname.new(path) }
files = files.uniq.select(&:file?)
errors = []

files.each do |file|
  base = file.to_s.delete_suffix(".md").delete_suffix(".vi")
  peer = file.to_s.end_with?(".vi.md") ? Pathname.new("#{base}.md") : Pathname.new("#{base}.vi.md")
  label = file.to_s.delete_prefix("#{root}/")
  errors << "#{label}: missing translation #{peer.basename}" unless peer.file?
  text = file.read
  errors << "#{label}: missing language switch to #{peer.basename}" unless text.include?(peer.basename.to_s)

  text.scan(/\]\(([^)]+)\)/).flatten.each do |target|
    next if target.match?(/\A(?:https?:|mailto:|#)/i)
    local = target.split("#", 2).first
    next if local.nil? || local.empty?
    resolved = file.dirname.join(local).cleanpath
    errors << "#{label}: broken local link #{target}" unless resolved.file?
  end
end

if errors.empty?
  puts "Bilingual docs and local links validated (#{files.count} Markdown files)."
else
  warn errors.uniq.join("\n")
  exit 1
end
