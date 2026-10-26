# Inbox table: one row per (source, event_id). The unique index is what turns
# at least once delivery into effectively once processing.
class ProcessedEvent < ActiveRecord::Base
end
