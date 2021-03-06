class GenieProcessorScreen < PM::Screen
  attr_accessor :should_break, :brain
  title "Calculating Best Deal..."

  def on_load
    set_nav_bar_button :right, system_item: :stop, action: :cancel

    @should_break = false

    setup_views

    Brain.app_brain.hostess = Hostesses.shared_hostess.current_hostess.copy
    perform_calculations
  end

  def setup_views
    rmq.stylesheet = GenieProcessorStylesheet
    rmq(self.view).apply_style :root_view

    container = rmq.append(UIView, :container)

    @small_stars = container.append(UIImageView, :small_stars)
    @small_stars2 = container.append(UIImageView, :small_stars2)
    @big_stars = container.append(UIImageView, :big_stars)
    container.append(UIImageView, :wand)

    container.append(UILabel, :working_magic)
    @progress = container.append(UIProgressView.alloc.initWithProgressViewStyle(UIProgressViewStyleDefault), :progress).get
  end

  def will_appear
    @view_set_up ||= begin
      [:small_stars, :small_stars2, :big_stars].each do |s|
        rmq(s).nudge(r: 30)
      end

      start_animating
    end
  end

  def start_animating
    # TODO - Fix bug where the animation doesn't start when invoked from Landscape mode

    transform = CATransform3DMakeRotation(Math::PI / 2.0, 0, 0, 1.0)

    animation = CABasicAnimation.animationWithKeyPath('transform')
    animation.toValue = NSValue.valueWithCATransform3D(transform)
    animation.duration = 2.25
    animation.cumulative = true

    animation.repeatCount = Float::MAX
    key = 'rotation_animation'
    @small_stars.get.layer.addAnimation(animation, forKey:key)

    animation.duration = 4.25
    @small_stars2.get.layer.addAnimation(animation, forKey:key)

    animation.duration = 8.25
    @big_stars.get.layer.addAnimation(animation, forKey:key)
  end

  def perform_calculations
    mp 'Start Processing'
    AppLogger.log("GENIE_STARTED")

    @progress.setProgress(0.0, animated:false)

    @jewelry_set = []

    # Loop through all the free jewelry and store copies of the objects
    Hostesses.shared_hostess.current_hostess.items.each do |item|
      item.qtyFree.to_i.times do |loop|
        @jewelry_set << item.copy
      end
      item.qtyHalfPrice.to_i.times do |loop|
        @jewelry_set << item.copy
      end
    end
    # puts "Jewelry Set:"
    # mp @jewelry_set

    Dispatch::Queue.concurrent('com.mohawkapps.theshowcloser.genie').async do
      start_time = NSDate.date
      # mp "Wishlist Array #{@jewelry_set}"

      # Now that we have the array, we need to loop through every combination
      # that exists and calculate which is the cheapest or leaves the least
      # amount of overage

      n = @jewelry_set.count
      total_allowed = 5000

      combinations = [:free, :half].cartesian_power(n, total_allowed)

      # Remove all combos that are not allowed
      combinations = combinations.reject do |c|
        half_count = c.select{|i| i == :half}.count
        (half_count > 1 && Brain.app_brain.h.jewelryPercentage.to_i == 20) || (half_count > 8) || (half_count > 6 && Brain.app_brain.h.showTotal < 500) || (half_count > 4 && Brain.app_brain.h.showTotal < 300)
      end

      # Limit total calculations to total_allowed
      combinations = combinations.sample(total_allowed) if combinations.count > total_allowed
      total_combos = combinations.count

      combinations.each_with_index do |combo, i|
        break if @should_break
        # Here's where the magic happens!

        # Set the brain's "fake" data
        if Brain.app_brain.jewelry_combo.nil?
          Brain.app_brain.jewelry_combo = {
            combo: combo,
            items: @jewelry_set
          }
        else
          Brain.app_brain.jewelry_combo[:combo] = combo
        end

        # Get the totals
        @b_dict = Brain.app_brain.calculate

        Dispatch::Queue.main.sync do
          @progress.setProgress((i + 1) / total_combos.to_f, animated:false)
        end

        # Compare it to the best combo
        if @best_combo.nil? || @b_dict[:totalDue] < @best_combo[:total_cost]
          @best_combo = Brain.app_brain.jewelry_combo.merge({
            free_left: @b_dict[:totalHostessBenefitsSix] - @b_dict[:freeTotal],
            total_cost: @b_dict[:totalDue]
          })
        end

      end

      unless @should_break
        stop_time = NSDate.date
        execution_time_sec = stop_time.timeIntervalSinceDate(start_time)
        timer_info = {
          time_to_complete: execution_time_sec,
          valid_permutations_count: total_combos
        }

        Dispatch::Queue.main.sync do
          AppLogger.log("GENIE_FINISHED_WITH_TIME", timer_info)
          cleanup

          # Show the summary screen.
          open GenieResultScreen.new(
            external_links: false,
            results: @best_combo,
            info: timer_info
          )
        end
      end
    end
  end

  def cancel
    AppLogger.log("GENIE_CANCELLED")
    cleanup
    close
  end

  def cleanup
    # Break out of the async process if it's still running
    @should_break = true

    # Set the brain back to the real data
    Brain.app_brain.jewelry_combo = nil
    Brain.app_brain.hostess = nil
  end

  def shouldAutorotate
    false
  end

  def supportedInterfaceOrientations
    UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown
  end

  def preferredInterfaceOrientationForPresentation
    UIInterfaceOrientationPortrait
  end

end
