require 'mechanize'
require 'nokogiri'
require 'csv'
require 'json'
require 'fileutils'

# Map category names to URLs
categories = {
  "French" => "https://ceresbookshop.com/fr/s/642/livres-d-%C3%A9dition-tunisienne",
  "Arabic" => "https://ceresbookshop.com/fr/s/644/livres-d-%C3%A9dition-arabe",
  "English" => "https://ceresbookshop.com/fr/s/643/livres-d-%C3%A9dition-fran%C3%A7aise",
  "School Books" => "https://ceresbookshop.com/fr/s/4774/livres-en-anglais",
  "Pedagogy" => "https://ceresbookshop.com/fr/s/647/livres-scolaires-et-p%C3%A9dagogie"
}

category_name = ARGV[0]
abort("❌ Category not specified or invalid") unless categories.key?(category_name)

category_url = categories[category_name]
genre = category_url.split('/').last.split('-').last
agent = Mechanize.new

books = []
current_url = category_url

loop do
  puts "🔍 Fetching: #{current_url}"
  page = agent.get(current_url)

  book_links = page.search('a.product_name').map { |link| link['href'] }.uniq

  book_links.each do |book_url|
    begin
      book_page = agent.get(book_url)

      title     = book_page.at('h1#aa_product_name')&.text&.strip || "N/A"
      author    = book_page.at('div#aa_product_author')&.text&.strip || "N/A"
      price     = book_page.at('span[itemprop="price"]')&.text&.strip || "N/A"
      publisher = book_page.at('dt:contains("Editeur") + dd')&.text&.strip || "N/A"
      isbn      = book_page.at('p.reference')&.text&.strip&.gsub('ISBN:', '') || "N/A"
      summary   = book_page.at('div.product-description p')&.text&.strip || "N/A"
      image_url = book_page.at('img.js-qv-product-cover')['src'] rescue "N/A"
      language  = book_page.at('dt.name:contains("Langue") + dd.value')&.text&.strip || "N/A"
      year      = book_page.at('dt.name:contains("Date de parution") + dd.value')&.text&.strip || "N/A"

      books << {
        title: title,
        author: author,
        price: price,
        publisher: publisher,
        isbn: isbn,
        summary: summary,
        image_url: image_url,
        language: language,
        year: year,
        genre: genre,
        book_url: book_url,
        category_url: category_url
      }

      puts "✔️ #{title}"
    rescue => e
      puts "⚠️ Failed to process #{book_url}: #{e.message}"
    end
  end

  next_link = page.at('a.next')
  break unless next_link
  current_url = next_link['href']
end

FileUtils.mkdir_p("output")

json_path = "output/#{category_name}.json"
csv_path  = "output/#{category_name}.csv"

File.write(json_path, JSON.pretty_generate(books))

CSV.open(csv_path, "wb") do |csv|
  csv << books.first.keys if books.any?
  books.each { |b| csv << b.values }
end

puts "✅ Done scraping #{category_name}: saved #{books.size} books to #{json_path} and #{csv_path}"
