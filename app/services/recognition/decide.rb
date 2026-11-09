module Recognition
  class Decide
    Result = Data.define(:decision, :identity, :score)

    def self.call(embedding:, profile:, policy:)
      raise ArgumentError, "Policy must be approved for the snapshotted profile" unless policy&.status == "approved" && policy.embedding_profile_id == profile.id
      literal = "[#{embedding.embedding.to_a.map(&:to_f).join(',')}]"
      expression = FaceEmbedding.sanitize_sql_array(["1 - (face_embeddings.embedding <=> CAST(? AS vector))", literal])
      rows = FaceEmbedding.where(embedding_profile_id: profile.id,
        face_image_id: FaceImage.enrollment_core.select(:id)).
        select("face_embeddings.face_image_id", "#{expression} AS cosine_score").
        order(Arel.sql("cosine_score DESC")).limit(2).to_a
      return Result.new(decision: "indeterminate", identity: nil, score: nil) if rows.empty?
      top, second = rows
      score = top.read_attribute("cosine_score").to_f
      return Result.new(decision: "unknown", identity: nil, score: score) if score < policy.threshold
      if policy.decision_margin && second && score - second.read_attribute("cosine_score").to_f < policy.decision_margin
        return Result.new(decision: "indeterminate", identity: nil, score: score)
      end
      Result.new(decision: "matched", identity: FaceImage.find(top.face_image_id).identity, score: score)
    end
  end
end
