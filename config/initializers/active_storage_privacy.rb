# Never expose Active Storage's default permanent public routes.
# Authenticated image downloads are served only through FaceImagesController.
Rails.application.config.active_storage.draw_routes = false
