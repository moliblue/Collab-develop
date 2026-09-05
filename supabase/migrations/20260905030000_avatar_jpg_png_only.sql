-- UC502: avatar uploads are limited to JPG/PNG files under the bucket's
-- existing 5 MB size limit.
update storage.buckets
set allowed_mime_types = array['image/jpeg', 'image/png']
where id = 'avatars';
