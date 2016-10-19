def cut(content)
  excerpt, cut, body = content.to_s.partition('<!--cut-->')
  excerpt +
    cut +
    '<div id="after_cut"></div>' +
    body
end

Jekyll::Hooks.register :posts, :pre_render do |document|
  document.content = cut(document.content)
end
