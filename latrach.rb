require 'mechanize'
require 'csv'
require 'json'
require 'uri'

# --- Helper to safely get a page with retry ---
def safe_get(agent, url, retries = 3)
  tries = 0
  begin
    agent.get(url)
  rescue => e
    tries += 1
    puts "⚠️ Error fetching #{url}: #{e.message} (try #{tries}/#{retries})"
    sleep(2 * tries)
    retry if tries < retries
    nil
  end
end

# --- Mechanize setup ---
agent = Mechanize.new
agent.user_agent_alias = 'Windows Chrome'

# --- Input and output ---
list_file = ARGV[0] || 'list.txt'
part_number = ARGV[1] || '0'

urls = File.readlines(list_file).map(&:strip)
csv_file = "books_part_#{part_number}.csv"
json_file = "books_part_#{part_number}.json"
done_file = "done_part_#{part_number}.txt"
urls = File.readlines(list_file).map(&:strip)
# --- Resume support ---
completed = File.exist?(done_file) ? File.readlines(done_file).map(&:strip) : []
urls.reject! { |url| completed.include?(url) }

# --- Data storage ---
books_data = []

CSV.open(csv_file, "wb") do |csv|
  csv << ["Title", "Author", "Year", "Publisher", "ISBN", "URL", "Category | Subcategory", "Image URL", "Price", "Summary"]

  urls.each do |url|
    next if completed.include?(url)
    puts "\n📚 Processing category: #{url}"
    base_url = url.split('?').first
    page_num = 1

    loop do
      paged_url = "#{base_url}?page=#{page_num}"
      puts "📄 Fetching page #{page_num}: #{paged_url}"

      page = safe_get(agent, paged_url)
      break unless page

      book_links = page.search('a.product_name.one_line')
      break if book_links.empty?

      book_links.each do |link|
        book_url = link['href']
        book_title = link.text.strip.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')

        puts "🔎 Scraping: #{book_title}"

        begin
          details_page = safe_get(agent, book_url)
          next unless details_page

          subcategory = book_url.split('/')[3].gsub('-', ' ')
          category = details_page.css('li[itemprop="itemListElement"]')[1]&.at('span[itemprop="name"]')&.text || 'N/A'

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

          sleep(rand(2..4))  # polite delay

        rescue => e
          puts "⚠️ Failed to scrape book at #{book_url}: #{e.message}"
          next
        end
      end
next_link = page.at('a.next')
  break unless next_link

   page_num += 1
    sleep(rand(2..4))
  end

  # ✅ Only mark category as done after finishing ALL its pages
  File.open(done_file, 'a') { |f| f.puts url }
end

# ✅ Write JSON at the very end
File.write(json_file, JSON.pretty_generate(books_data, indent: '  '))

puts "\n✅ Scraping completed. Exported #{books_data.size} books to:"
puts "- #{csv_file}"
puts "- #{json_file}"
