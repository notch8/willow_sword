Rails.application.config.to_prepare do
  if defined?(Hyrax::Resource)
    Hyrax::Resource.delegate(
      :visibility_during_embargo, :visibility_after_embargo, :embargo_release_date,
      to: :embargo, allow_nil: true
    )

    Hyrax::Resource.delegate(
      :visibility_during_lease, :visibility_after_lease, :lease_expiration_date,
      to: :lease, allow_nil: true
    )
  end
end
