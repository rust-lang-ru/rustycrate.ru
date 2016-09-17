def typografy(filename)
  if filename.end_with?('.html')
    `typograf -l ru #{filename} | sponge #{filename}`
  end
end

Jekyll::Hooks.register :pages, :post_write do |document|
  filename = document.destination(document.site.dest)
  typografy(filename)
end

Jekyll::Hooks.register :posts, :post_write do |document|
  filename = document.destination(document.site.dest)
  typografy(filename)
end
