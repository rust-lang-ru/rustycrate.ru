def eyoify(file)
  if file.end_with?('.html')
    stdout = `eyo #{file}`
    File.write(file, stdout)
  end
end

if ENV['RUSTYCRATE_MODE'] == 'production' and
   ENV['RUSTYCRATE_ENABLE_EYO'] == 'yes'

  Jekyll::Hooks.register :pages, :post_write do |document|
    file = document.destination(document.site.dest)
    eyoify(file)
  end

  Jekyll::Hooks.register :posts, :post_write do |document|
    file = document.destination(document.site.dest)
    eyoify(file)
  end
end
