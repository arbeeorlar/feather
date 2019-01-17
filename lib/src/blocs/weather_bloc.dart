import 'dart:async';

import 'package:feather/src/models/internal/geo_position.dart';
import 'package:feather/src/models/remote/weather_forecast_list_response.dart';
import 'package:feather/src/models/remote/weather_response.dart';
import 'package:feather/src/resources/location_manager.dart';
import 'package:feather/src/resources/storage_manager.dart';
import 'package:feather/src/resources/weather_repository.dart';
import 'package:logging/logging.dart';
import 'package:rxdart/rxdart.dart';

class WeatherBloc {
  final _weatherRepository = WeatherRepository();
  final _locationManager = LocationManager();
  final _storageManager = StorageManager();
  final _weatherFetcher = PublishSubject<WeatherResponse>();
  final _weatherForecastFetcher = PublishSubject<WeatherForecastListResponse>();
  final _weatherRefreshTimeInSeconds = 900;
  final _logger = new Logger("WeatherBloc");

  Observable<WeatherResponse> get weather => _weatherFetcher.stream;

  Observable<WeatherForecastListResponse> get weatherForecast =>
      _weatherForecastFetcher.stream;

  fetchWeatherForUserLocation() async {
    _logger.log(Level.FINE, "Fetch weather for user location");

    GeoPosition geoPosition = await _getPosition();
    if (geoPosition != null){
      fetchWeather(geoPosition.lat, geoPosition.long);
    } else {
      _logger.log(
          Level.WARNING,
          "Fetch weather failed because location not selected");
      _weatherFetcher.sink
          .add(WeatherResponse.withErrorCode("ERROR_LOCATION_NOT_SELECTED"));
    }

  }

  fetchWeather(double latitude, double longitude) async {
    _logger.log(Level.FINE, "Fetch weather");
    WeatherResponse weatherResponse =
        await _weatherRepository.fetchWeather(latitude, longitude);
    if (weatherResponse.errorCode == null) {
      _storageManager.saveWeather(weatherResponse);
    } else {
      _logger.info("Selected weather from storage");
      WeatherResponse weatherResponseStorage =  await _storageManager.getWeather();
      if (weatherResponseStorage != null){
        weatherResponse = weatherResponseStorage;
      }
    }
    _weatherFetcher.sink.add(weatherResponse);
  }

  fetchWeatherForecastForUserLocation() async {
    _logger.log(Level.FINE, "Fetch weather forecast for user location");

    GeoPosition geoPosition = await _getPosition();
    if (geoPosition != null){
      fetchWeatherForecast(geoPosition.lat, geoPosition.long);
    } else {
      _logger.log(Level.WARNING,
          "Fetch weather forecast for user location failed because location not selected");
      _weatherForecastFetcher.sink.add(
          WeatherForecastListResponse.withErrorCode(
              "ERROR_LOCATION_NOT_SELECTED"));
    }
  }

  fetchWeatherForecast(double latitude, double longitude) async {
    _logger.log(Level.FINE, "Fetch weather forecast");
    WeatherForecastListResponse weatherForecastResponse =
        await _weatherRepository.fetchWeatherForecast(latitude, longitude);
    if (weatherForecastResponse.errorCode == null){
      _storageManager.saveWeatherForecast(weatherForecastResponse);
    } else {
      WeatherForecastListResponse weatherForecastResponseStorage = await _storageManager.getWeatherForecast();
      if (weatherForecastResponseStorage != null){
        weatherForecastResponse = weatherForecastResponseStorage;
        _logger.info("Using weather forecast data from storage");
      }
    }

    _weatherForecastFetcher.sink.add(weatherForecastResponse);
  }

  setupTimer() {
    _logger.log(Level.FINE, "Setup timer");
    var duration = Duration(seconds: _weatherRefreshTimeInSeconds);
    new Timer(duration, handleTimerTimeout);
  }

  handleTimerTimeout() {
    _logger.log(Level.FINE, "handle timer timeout");
    setupTimer();
    fetchWeatherForUserLocation();
    fetchWeatherForecastForUserLocation();
  }


  Future<GeoPosition> _getPosition() async {
    var positionOptional = await _locationManager.getLocation();
    if (positionOptional.isPresent) {
      _logger.fine("Position is present!");
      var position = positionOptional.value;
      GeoPosition geoPosition = GeoPosition.fromPosition(position);
      _storageManager.saveLocation(geoPosition);
      return geoPosition;
    } else {
      _logger.fine("Position is not present!");
      return _storageManager.getLocation();
    }
  }



  dispose() {
    _logger.log(Level.FINE, "Dispose");
    _weatherFetcher.close();
    _weatherForecastFetcher.close();
  }


}

final bloc = WeatherBloc();