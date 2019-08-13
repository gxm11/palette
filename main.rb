# encoding: utf-8

require "chunky_png"
require "matrix"
require "fileutils"
require "json"

begin
  $config = JSON.load(File.read("palette.json"))
rescue
  data = {
    train: {
      from: "red.png", to: "green.png", cluster: "cluster.png",
      episodes: 10, max_cluster_number: 6,
      weights: { x: 0.03, y: 0.3, r: 1.0, g: 1.0, b: 1.0, a: 0.0 },
    },
    convert: {
      from: "red_4x4.png", to: "green_4x4.png",
      x_split: 4, y_split: 4,
    },
  }
  File.open("palette.json", "w") { |f|
    f << JSON.pretty_generate(data)
  }
  puts "Please change configs in palette.json"
  exit()
end

module Generator
  # Tuning Constants
  Feature_Weights = Matrix.diagonal(*("xyrgba".split("").collect { |k|
    $config["train"]["weights"][k]
  }))

  Max_Cluster_Number = $config["train"]["max_cluster_number"]
  Train_Episodes = $config["train"]["episodes"]

  # Fixed Constants
  Feature_Number = 6

  module_function

  def train(red, green, draw = true)
    @red = ChunkyPNG::Image.from_file(red)
    @green = ChunkyPNG::Image.from_file(green)
    w, h = @red.width, @red.height
    m_red = img2matrix(@red)
    cluster_center = nil
    for i in 0..Train_Episodes
      cluster_index = find_cluster_index(m_red, cluster_center)
      cluster_center = find_next_cluster(m_red, cluster_index)
    end
    cluster_index = find_cluster_index(m_red, cluster_center)
    if draw
      draw_cluster_images(cluster_index, $config["train"]["cluster"])
    end
    cluster_points = {}
    cluster_index.column(0).to_a.each_with_index { |v, index|
      cluster_points[v] ||= []
      cluster_points[v].push([[index % w, index / w], m_red.row(index)])
    }
    return [cluster_center, cluster_points]
  end

  def draw_cluster_images(cluster_index, fn)
    w, h = @red.width, @red.height
    indexes = cluster_index.column(0).to_a.uniq
    _img = ChunkyPNG::Image.new(w * indexes.size, h * 2)
    for i in 0...indexes.size
      for x in 0...w
        for y in 0...h
          j = x + y * w
          if cluster_index[j, 0] == indexes[i]
            _img[x + i * w, y] = @red[x, y]
            _img[x + i * w, y + h] = @green[x, y]
          end
        end
      end
    end
    _img.save(fn)
  end

  def img2matrix(img)
    h, w = img.height, img.width
    m = Matrix.build(h * w, Feature_Number) { |row, col|
      x = row % w
      y = row / w
      color = img[x, y]
      case col
      # [X, Y, R, G, B, A]
      when 0 then x
      when 1 then y
      when 2 then color >> 24
      when 3 then (color >> 16) & 0xff
      when 4 then (color >> 8) & 0xff
      when 5 then color & 0xff
      end
    }
    m * Matrix.diagonal(1.0 / w, 1.0 / h, 1.0 / 255, 1.0 / 255, 1.0 / 255, 1.0 / 255)
  end

  def feature_distance(v1, v2)
    d = v1 - v2
    (d.to_matrix.t * Feature_Weights * d)[0]
  end

  def find_cluster_index(m_points, cluster_center = nil)
    if cluster_center == nil
      rand_points = Array.new(Max_Cluster_Number) {
        m_points.row(rand(m_points.row_size))
      }
      cluster_center = Matrix[*rand_points]
    end
    cluster_index = Matrix.build(m_points.row_size, 1) { |m_index, _|
      min_dis, min_i = Float::INFINITY, Max_Cluster_Number
      cluster_center.row_vectors.each_with_index { |center, i|
        dis = feature_distance(m_points.row(m_index), center)
        if dis < min_dis
          min_dis, min_i = dis, i
        end
      }
      min_i
    }
    return cluster_index
  end

  def find_next_cluster(m_points, cluster_index)
    new_cluster_points = Array.new(Max_Cluster_Number) { [] }
    cluster_index.column(0).to_a.each_with_index { |c_index, row|
      new_cluster_points[c_index].push(m_points.row(row))
    }
    _cluster_center = new_cluster_points.collect { |points|
      next if points.empty?
      points.inject(Vector.zero(Feature_Number), &:+) / points.size
    }.compact
    cluster_center = Matrix[*_cluster_center]
    return cluster_center
  end

  def convert!(img, cluster_center, cluster_points)
    w, h = img.width, img.height
    m = img2matrix(img)
    cluster_index = find_cluster_index(m, cluster_center)
    for x in 0...w
      for y in 0...h
        next if img[x, y] & 255 == 0
        j = x + y * w
        c_index = cluster_index[j, 0]
        nn = cluster_points[c_index].min_by { |pos, point|
          feature_distance(point, m.row(j))
        }
        img[x, y] = @green[nn[0][0], nn[0][1]]
      end
    end
    img
  end
end

include Generator
red, green = $config["train"]["from"], $config["train"]["to"]
red_4x4, green_4x4 = $config["convert"]["from"], $config["convert"]["to"]
x_split, y_split = $config["convert"]["x_split"], $config["convert"]["y_split"]

puts "Start Train..."
t = Time.now
cluster_center, cluster_points = train(red, green)
image = ChunkyPNG::Image.from_file(red_4x4)
w, h = image.width / x_split, image.height / y_split
new_image = ChunkyPNG::Image.new(image.width, image.height)

puts "Find #{cluster_points.keys.size} clusters in %.2f s." % (Time.now - t)

puts "Start convert image..."
t = Time.now
for i in 0...x_split
  for j in 0...y_split
    print "\e[100DConvert slice #{i * y_split + j + 1} / #{x_split * y_split}..."
    img = image.crop(i * w, j * h, w, h)
    convert!(img, cluster_center, cluster_points)
    new_image.compose!(img, i * w, j * h)
    new_image.save(green_4x4)
  end
end
puts "\e[100DConvert #{x_split * y_split} slices in %.2f s." % (Time.now - t)
puts "Save to #{green_4x4}."