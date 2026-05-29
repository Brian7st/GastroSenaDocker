# El build de Angular se corre localmente antes de construir la imagen:
#   npx nx build restaurant-app --configuration=production
#
# Esta imagen solo toma el output ya compilado y lo sirve con nginx.
FROM nginx:1.27-alpine

COPY dist/apps/restaurant-app/browser /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 4200

CMD ["nginx", "-g", "daemon off;"]
