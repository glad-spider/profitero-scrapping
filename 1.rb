require 'open-uri'
require 'nokogiri'
require 'csv'


def get_document_page(html_path)
  return Nokogiri::HTML.parse(URI.open(html_path))
end

def get_content_from_page(document, x_path, action)
  document.xpath(x_path).each do |_content|
    return action.call(_content)
  end
end

$x_path_comb_price_weight_frt = '//*[@class="attribute_list"]/ul/li/label/span[2]'
$x_path_comb_price_weight_scd = '//*[@class="attribute_list"]/ul/li[2]/label/span[2]'
$x_path_product_mane          = '//*[@id="center_column"]/div/div[2]/div[2]/div[1]/div/h1'
$x_path_product_img           = '//*[@id="bigpic"]'
$x_path_product_weight1       = '//*[@class="attribute_list"]/ul/li/label/span'
$x_path_product_weight2       = '//*[@class="attribute_list"]/ul/li[2]/label/span'

$get_product_main_name = -> (text) { return text.content }
$get_product_weight    = -> (text) { return text.content }
$get_price_comb        = -> (price) { return price.content.split(' ')[0] }


def try_get_info(links_pages = [], parsing_content = [])
  for i in 0..links_pages.length - 1
    pp "extract content from link(%s): %s" % [i + 1, links_pages[i][0]]
    document = get_document_page(links_pages[i][0])

    parsing_content.append(
      {
        "name"=> get_content_from_page(document, $x_path_product_mane, $get_product_main_name),
        "price 1" => get_content_from_page(document, $x_path_comb_price_weight_frt, $get_price_comb),
        "price 2"=> get_content_from_page(document, $x_path_comb_price_weight_scd, $get_price_comb),
        "weight 1"=> get_content_from_page(document, $x_path_product_weight1, $get_product_weight),
        "weight 2"=> get_content_from_page(document, $x_path_product_weight2, $get_product_weight),
        "image"=> document.xpath($x_path_product_img).map { |t| t[:src] }[0]
      })
  end

  return parsing_content
end

def set_head_csv(flname = ARGV[1])
  CSV.open(flname, "w") do |csv|
    csv << ["Name", "Price", "Image"]
  end
end

def append_to_csv(data, flname = ARGV[1])
  pp "append data to CSV file"
  CSV.open(flname, "a") do |csv|
    i = 0
    while i < data.length - 1
      #check that the product have two price
      if data[i]["price 2"].length == 0
        cell_name = "%s %s" % [data[i]["name"], data[i]["weight 1"]]
        cell_price = data[i]["price 1"]
        cell_image = data[i]["image"]
        csv << [cell_name, cell_price, cell_image]
        i += 1
      else
        cell_name = "%s %s" % [data[i]["name"], data[i]["weight 1"]]
        cell_price = data[i]["price 1"]
        cell_image = data[i]["image"]
        csv << [cell_name, cell_price, cell_image]

        cell_name = "%s %s" % [data[i]["name"], data[i]["weight 2"]]
        cell_price = data[i]["price 2"]
        cell_image = data[i]["image"]
        csv << [cell_name, cell_price, cell_image]
        i += 1
      end
    end
  end
end

def all_list_products(doc_category, is_full_access = true)
  links_products = []
  i = 0
  begin
    i += 1
    x_path_product = '//*[@id="product_list"]/li[%s]/div[1]/div[1]/div[1]/link[1]' % [i]
    f = doc_category.xpath(x_path_product).map { |t| t[:href] }
    if f.length != 0
      links_products.append(f)
    else
      pp "count of products on page = %s" % [i-1]
      return links_products
    end
  end while is_full_access

  return links_products
end

def scraping()
  set_head_csv()

  i = 0
  is_exsist_page = true
  while is_exsist_page
    i += 1
    url = "%s?p=%s" % [ARGV[0], i]
    pp "pasring page %s" % [url]

    document_category = get_document_page(url)

    #get all links products on page
    list_links = all_list_products(document_category)

    products = try_get_info(list_links)
    append_to_csv(products)

    if i > 1
      pp 'Check next page on dublicates'
      j = i + 1 #проверить что след страница это не нынешняя(последняя)
      url = "%s?p=%s" % [ARGV[0], j]
      _document_category = get_document_page(url)
      first_link = all_list_products(_document_category, false)
      product = try_get_info(first_link)#передать ссылку на первый товар

      p "check on matching"
      # open('myfile.out', 'a') do |f|
      #   f << "and again ...\n"
      # end
      CSV.foreach(ARGV[1]) { |row|

        # 0 is not matching
        # 1 is matching
        # p "%s == %s" % [row[0], product[0]['name']]
        if row[0].match(product[0]['name']).to_s != ""
          pp "find duplicate of product, it is was last page"
          is_exsist_page = false
          break
        end
        }
    end
    puts("executed  extract content from page %s: ..." % [i])
  end
  pp "scraping is done, look in %s" % [ARGV[1]]
end

scraping


