def typografy(file)
  if file.end_with?('.html')
    stdout = `typograf -l ru #{file}`
    File.write(file, stdout)
  end
end

Jekyll::Hooks.register :pages, :post_write do |document|
  file = document.destination(document.site.dest)
  typografy(file)
end

Jekyll::Hooks.register :posts, :post_write do |document|
  file = document.destination(document.site.dest)
  typografy(file)
end
