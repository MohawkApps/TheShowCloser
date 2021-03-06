class NSDate
  def short_date
    dateFormatter = NSDateFormatter.alloc.init
    dateFormatter.setTimeStyle(NSDateFormatterNoStyle)
    dateFormatter.setDateStyle(NSDateFormatterMediumStyle)
    dateFormatter.stringFromDate(self)
  end

  def full_date
    dateFormatter = NSDateFormatter.alloc.init
    dateFormatter.setDateStyle(NSDateFormatterLongStyle)
    dateFormatter.stringFromDate(self)
  end

  def later_than?(other_date)
	   (self.compare(other_date) == NSOrderedDescending)
  end
end
