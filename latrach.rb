require 'mechanize'
require 'csv'
require 'json'

# Initialize Mechanize
agent = Mechanize.new
agent.user_agent_alias = 'Windows Chrome'

list_file = ARGV[0] || 'list.txt'
part_number = ARGV[1] || '0'

urls = File.readlines(list_file).map(&:strip)
books_data = []

CSV.open("books_data.csv", "wb") do |csv|
  csv << ["Title", "Author", "Year", "Publisher", "ISBN", "URL", "Category | Subcategory", "Image URL", "Price", "Summary"]

  urls.each do |url|
    puts "Processing URL: #{url}"
 base_url = url.split('?').first
page_num = 1

loop do
  paged_url = "#{base_url}?page=#{page_num}"
  puts "📄 Fetching page #{page_num}: #{paged_url}"

  begin
    page = agent.get(paged_url)
    puts "Page title: #{page.title}"

    book_links = page.search('a.product_name.one_line')
    break if book_links.empty?  # stop if no books found

    book_links.each do |link|
      book_url = link['href']
      book_title = link.text.strip
      puts "🔎 Scraping: #{book_title}"

      begin
        details_page = agent.get(book_url)

        subcategory = book_url.split('/')[3].gsub('-', ' ')
        category = details_page.css('li[itemprop="itemListElement"]').at(1)&.at('span[itemprop="name"]')&.text || 'N/A'
        author = details_page.at('.product-manufacturer a')&.text&.strip || 'N/A'
        isbn = details_page.at('.product-reference span[itemprop="sku"]')&.text&.strip || 'N/A'
        year = details_page.at('dt.name:contains("سنة النشر") + dd.value')&.text&.strip || 'N/A'
        publisher = details_page.at('dt.name:contains("دار النشر") + dd.value')&.text&.strip || 'N/A'
        image_url = details_page.at('div.easyzoom a')&.[]('href') || 'N/A'
        price = details_page.at('.price')&.text&.strip || 'N/A'
        summary = details_page.at('.product-description')&.text&.strip || 'N/A'

        csv << [book_title, author, year, publisher, isbn, book_url, "#{category} | #{subcategory}", image_url, price, summary]

        books_data << {
          title: book_title,
          author: author,
          year: year,
          publisher: publisher,
          isbn: isbn,
          url: book_url,
          category: "#{category} | #{subcategory}",
          image_url: image_url,
          price: price,
          summary: summary,
          pageurl: paged_url
        }

        sleep(rand(1..3))
      rescue => e
        puts "⚠️ Failed to scrape book at #{book_url}: #{e.message}"
        next
      end
    end

    page_num += 1
    sleep(rand(1..3))
  rescue => e
    puts "❌ Error on page #{page_num}: #{e.message}"
    break
  end
end


# Write JSON output once at the end
File.write("books_part_#{part_number}.json", JSON.pretty_generate(books_data))
File.write("books_data.json", JSON.pretty_generate(books_data))

puts "✅ Scraping completed. Exported to books_data.csv and books_part_#{part_number}.json."
