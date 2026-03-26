package com.credtrack.backend.service;

import com.credtrack.backend.entity.User;
import com.credtrack.backend.repository.UserRepository;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.Optional;

@Service
public class UserService {

    private final UserRepository userRepository;

    public UserService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    public User createOrUpdateUser(User user) {

        Optional<User> existingUser = userRepository.findById(user.getId());

        if (existingUser.isPresent()) {
            User existing = existingUser.get();
            existing.setLastLogin(LocalDateTime.now());
            return userRepository.save(existing);
        }

        user.setCreatedAt(LocalDateTime.now());
        user.setLastLogin(LocalDateTime.now());

        return userRepository.save(user);
    }

    public Optional<User> getUserById(String id) {
        return userRepository.findById(id);
    }
}