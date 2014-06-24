class MasterJewelryScreen < PM::TableScreen
  searchable

  def on_load
    @data ||= [{
      title: 'Loading...',
      selection_style: UITableViewCellSelectionStyleNone
    }]
  end

  def on_appear
    cells

    @reload_observer = App.notification_center.observe 'ReloadJewelryTableNotification' do |notification|
      cells
    end
  end

  def on_disappear
    App.notification_center.unobserve @reload_observer
  end

  def table_data
    [{
      title: nil,
      cells: @data
    }]
  end

  def cells
    # TODO - mke this into sections by letter name
    @data = JewelryData.sorted.collect do |j|
      build_cell(j)
    end
    update_table_data
  end

  def cell_title(data)
    data['name']
  end

  def cell_subtitle(data)
    "Item: #{data['item']}, $#{data['price'].to_i}#{page_number(data)}"
  end

  def page_number(item)
    p = item['pages']
    return "" unless p.is_a?(Array)

    case p.count
    when 1
      ", Page: #{p.first}"
    else
      ", Pages: #{p.join(', ')}"
    end
  end

  # Cell data

  def build_cell(data)
    cell_data(data).merge({
      selection_style: UITableViewCellSelectionStyleNone
    })
  end

  def build_free_cell(data)
    ch = Hostesses.shared_hostess.current_hostess

    cell_data(data).merge({
      action: :toggle_free,
      long_press_action: :show_free_qty_picker,
      image: ch.has_free?(data['item']) ? UIImage.cellImageWithText(ch.free_count(data['item'])) : 'normal',
    })
  end

  def build_halfprice_cell(data)
    ch = Hostesses.shared_hostess.current_hostess

    cell_data(data).merge({
      action: :toggle_halfprice,
      long_press_action: :show_halfprice_qty_picker,
      image: ch.has_halfprice?(data['item']) ? UIImage.cellImageWithText(ch.halfprice_count(data['item'])) : 'normal',
    })
  end

  def cell_data(data)
    {
      title: cell_title(data),
      subtitle: cell_subtitle(data),
      search_text: data['item'],
      cell_style: UITableViewCellStyleSubtitle,
      selection_style: UITableViewCellSelectionStyleDefault,
      arguments: {
        item: data['item']
      }
    }
  end

  #Toggling

  def toggle_free(args)
    toggle_item(args[:item], true)
  end

  def toggle_halfprice(args)
    toggle_item(args[:item], false)
  end

  def toggle_item(item, free)
    ch = Hostesses.shared_hostess.current_hostess

    if free
      qty = (ch.has_free?(item)) ? 0 : 1
      ch.set_free(item, qty)
    else
      qty = (ch.has_halfprice?(item)) ? 0 : 1
      ch.set_halfprice(item, qty)
    end
    update_table_data
  end

  # Clearing

  def clear(kind = :all)
    case kind
    when :free
      title = 'Clear all free items?'
      message = 'Are you sure you want to clear all free hostess selections?'
    when :halfprice
      title = 'Clear all half price items?'
      message = 'Are you sure you want to clear all half price hostess selections?'
    else
      title = 'Clear all items?'
      message = 'Are you sure you want to clear all hostess selections? This can not be undone.'
    end

    BW::UIAlertView.new({
      title: title,
      message: message,
      buttons: ['No', 'Yes'],
      cancel_button_index: 0
    }) do |alert|
      unless alert.clicked_button.cancel?
        case kind
        when :free
          Hostesses.shared_hostess.current_hostess.clear_free
        when :halfprice
          Hostesses.shared_hostess.current_hostess.clear_halfprice
        else
          Hostesses.shared_hostess.current_hostess.clear_free
          Hostesses.shared_hostess.current_hostess.clear_halfprice
        end
        update_table_data
      end
    end.show
  end

  def clear_all_free
    clear(:free)
  end

  def clear_all_halfprice
    clear(:halfprice)
  end

  def clear_all
    clear(:all)
  end

  # Picker

  def show_free_qty_picker(args)
    show_qty_picker(args[:item], true)
  end

  def show_halfprice_qty_picker(args)
    show_qty_picker(args[:item], false)
  end

  def show_qty_picker(item, free)
    ch = Hostesses.shared_hostess.current_hostess

    # Get the initial index for the picker
    initial_index = 0
    if free && ch.has_free?(item)
      initial_index = ch.free_count(item)
    elsif !free && ch.has_halfprice?(item)
      initial_index = ch.halfprice_count(item)
    end

    ActionSheetStringPicker.showPickerWithTitle(
      "Select Qty",
      rows: (0..10).to_a.map{ |i| i.to_s },
      initialSelection: initial_index,
      doneBlock: -> picker, index, value {
        ap "Picked Qty: #{value}"

        if free
          ch.set_free(item, value)
        else
          ch.set_halfprice(item, value)
        end
        update_table_data
      },
      cancelBlock: -> picker {
        ap "Canceled the picker"
      },
      origin: self.view)
  end
end
