require 'mechanize'
require 'csv'
require 'json'

# Initialize a new Mechanize agent
agent = Mechanize.new

# Get the list file name from command-line args or default to 'list.txt'
list_file = ARGV[0] || 'list.txt'
part_number = ARGV[1] || '0'

# Read URLs from the list file
urls = File.readlines(list_file).map(&:strip)

# Array to hold book data for JSON export
books_data = []

begin
  # Open a CSV file for writing
  CSV.open("books_data.csv", "wb") do |csv|
    # Write the header row
    csv << ["Title", "Author", "Year", "Publisher", "ISBN", "URL", "Category | Subcategory", "Image URL", "Price", "Summary"]

    # Loop through each URL
    urls.each do |url|
      puts "Processing URL: #{url}"

      # Start scraping the initial URL
      loop do
        page = agent.get(url)
        puts "Page title: #{page.title}"

        # Find all book links on the current page
        book_links = page.search('a.product_name.one_line')

        # Loop through each book link to scrape details
        book_links.each do |link|
          book_url = link['href']
          book_title = link.text.strip
          puts "Scraping details for: #{book_title}, URL: #{book_url}"
begin
          # Follow the link to the details page
          details_page = agent.get(book_url)

          # Extract subcategory from the book URL
          subcategory = book_url.split('/')[3].gsub('-', ' ')
          puts "Extracted subcategory: #{subcategory}" # Debugging output
          category = details_page.css('li[itemprop="itemListElement"]').at(1).css('span[itemprop="name"]').text

          # Scrape author (default to nil if not found)
          author = details_page.at('.product-manufacturer a')&.text&.strip || 'N/A'
          puts "Found author: #{author}" # Debugging output

          # Scrape ISBN (default to nil if not found)
          isbn = details_page.at('.product-reference span[itemprop="sku"]')&.text&.strip || 'N/A'
          puts "Found ISBN: #{isbn}" # Debugging output

          # Scrape year (default to nil if not found)
          year = details_page.at('dt.name:contains("سنة النشر") + dd.value')&.text&.strip || 'N/A'
          puts "Found year: #{year}" # Debugging output

          # Scrape publisher (default to nil if not found)
          publisher = details_page.at('dt.name:contains("دار النشر") + dd.value')&.text&.strip || 'N/A'
          puts "Found publisher: #{publisher}" # Debugging output

          # Scrape image URL (default to nil if not found)
            # Prefer the high-res image URL
        image_url = details_page.at('div.easyzoom a')&.[]('href') || 'N/A'


          #image_url = details_page.at('img.product-image')&.[]('src') || 'N/A'
          puts "Found image URL: #{image_url}" # Debugging output

          # Scrape price (default to nil if not found)
          price = details_page.at('.price')&.text&.strip || 'N/A'
          puts "Found price: #{price}" # Debugging output

          # Scrape summary (default to nil if not found)
          summary = details_page.at('.product-description')&.text&.strip || 'N/A'
          puts "Found summary: #{summary}" # Debugging output

          # Print the final output for the book
          puts "Title: #{book_title}"
          puts "Author: #{author}"
          puts "Year: #{year}"
          puts "Publisher: #{publisher}"
          puts "ISBN: #{isbn}"
          puts "Category: #{category} | Subcategory: #{subcategory}"
          puts "URL: #{book_url}"
          puts "Image URL: #{image_url}"
          puts "Price: #{price}"
          puts "Summary: #{summary}"
          puts "pageurl: #{url}"
          puts "-" * 40 # Separator for readability

          # Write the data to the CSV file
          csv << [book_title, author, year, publisher, isbn, book_url, "#{category} | #{subcategory}", image_url, price, summary]
 # Add book data to the array for JSON export
          books_data << {
            title: book_title,
            author: author,
            year: year,
            publisher: publisher,
            isbn: isbn,
            url: book_url,
            category: "#{category}
| #{subcategory}",
            image_url: image_url,
            price: price,
            summary: summary,
            pages: url
          }
File.open("books_data.json", "w") do |f|
  f.write(JSON.pretty_generate(books_data))
end
sleep(rand(1..3)) 
rescue => e
  puts "⚠️ Failed to scrape book at #{book_url}: #{e.message}"
  next
end
end

         
      
# Check for the "next" link
        next_link = page.at('a.next')
        break unless next_link # Exit the loop if there is no next link

        # Update the URL to the next page
        url = next_link['href']
sleep(rand(1..3)) 

end
end
end

rescue => e
  puts "Failed to scrape: #{e.message}"

end
      # Save progress after processing this page
      File.open("books.json", "w") do |f|
        f.write(JSON.pretty_generate(books))
      end

      # Check for next page link
      next_page = page.at('a.next')
      break unless next_page

      url = next_page['href']
    #end
  rescue => e
    puts "Error processing URL #{url}: #{e.message}"
  end
end

# Write final results at end
File.write("books_part_#{part_number}.json", JSON.pretty_generate(books))
File.write("books.json", JSON.pretty_generate(books))

puts "Scraping completed. Data exported to books.csv and books_part_#{part_number}.json."
